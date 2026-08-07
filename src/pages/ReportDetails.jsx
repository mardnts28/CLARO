import { useState, useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import DashboardLayout from "../components/DashboardLayout";
import ConfirmModal from "../components/ConfirmModal";
import FdaVerificationModal from "../components/FdaVerificationModal";
import { getReportById, approveReport, rejectReport } from "../services/reportService";
import { CANONICAL_ALLERGENS } from "../constants/canonicalAllergens";
import { FiArrowLeft } from "react-icons/fi";
import { doc, getDoc } from "firebase/firestore";
import { db } from "../firebase/firebase";
import "./ReportDetails.css";

function StatusBadge({ status }) {
  const map = {
    Approve: "badge badge-approved",
    Pending: "badge badge-pending",
    Rejected: "badge badge-rejected",
  };
  return <span className={map[status] || "badge"}>{status}</span>;
}

// Product category options for dropdown
const PRODUCT_CATEGORIES = [
  "Canned Fish",
  "Canned Seafood", 
  "Canned Meat",
  "Canned Vegetables",
  "Instant Noodles",
  "Other",
];

// Nutrition fields shown in the review grid -- keys match exactly what
// ProductExtractionResult.toReportExtractedDataMap() writes under
// extractedData.nutrition (see the Flutter app's product_extraction_result.dart).
const NUTRITION_FIELDS = [
  { key: "calories_kcal", label: "Calories", unit: "kcal" },
  { key: "protein_g", label: "Protein", unit: "g" },
  { key: "carbs_g", label: "Carbs", unit: "g" },
  { key: "fat_total_g", label: "Total Fat", unit: "g" },
  { key: "fat_saturated_g", label: "Saturated Fat", unit: "g" },
  { key: "fat_trans_g", label: "Trans Fat", unit: "g" },
  { key: "sodium_mg", label: "Sodium", unit: "mg" },
  { key: "potassium_mg", label: "Potassium", unit: "mg" },
  { key: "calcium_mg", label: "Calcium", unit: "mg" },
  { key: "iron_mg", label: "Iron", unit: "mg" },
  { key: "fiber_g", label: "Fiber", unit: "g" },
  { key: "sugars_g", label: "Sugars", unit: "g" },
  { key: "added_sugars_g", label: "Added Sugars", unit: "g" },
];

// Builds the editable form state from whatever's already on
// report.extractedData -- empty/missing extractedData (extraction still
// processing, timed out, or failed) just means every field starts blank,
// so admin can still fill it in manually rather than being blocked.
function buildFormState(extractedData) {
  const ed = extractedData || {};
  const nutrition = ed.nutrition || {};
  const nutritionState = {};
  NUTRITION_FIELDS.forEach(({ key }) => {
    nutritionState[key] = nutrition[key] ?? 0;
  });

  // Helper to extract numeric value from size strings like "155g" or "1/2 cup (65g)"
  function extractGrams(value) {
    if (!value) return "";
    if (typeof value === 'number') return value;
    // Try to extract number from string
    const match = value.toString().match(/(\d+)/);
    return match ? Number(match[1]) : "";
  }

  // Determine if category matches a predefined option or is custom
  const categoryValue = ed.category || "";
  const categoryLower = categoryValue.toLowerCase().trim();
  const matchedCategory = PRODUCT_CATEGORIES.find(cat => cat.toLowerCase() === categoryLower);
  
  let selectedCategory = "";
  let customCategory = "";
  
  if (categoryValue) {
    if (matchedCategory) {
      selectedCategory = matchedCategory;
    } else {
      selectedCategory = "Other";
      customCategory = categoryValue;
    }
  }
  
  return {
    brand: ed.brand || "",
    productName: ed.productName || "",
    category: selectedCategory,
    customCategory: customCategory,
    size: extractGrams(ed.size),
    servingSize: extractGrams(ed.servingSize),
    ingredients: (ed.ingredients || []).join("\n"),
    allergens: ed.allergens || [],
    nutrition: nutritionState,
    confidenceNotes: ed.confidenceNotes || "",
  };
}

export default function ReportDetails() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [report, setReport] = useState(null);
  const [form, setForm] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [modalType, setModalType] = useState(null); // "approve" | "reject" | null
  const [actionLoading, setActionLoading] = useState(false);
  const [lightbox, setLightbox] = useState(null); // image url or null
  const [selectedCategory, setSelectedCategory] = useState("");
  const [reporterName, setReporterName] = useState("");

  useEffect(() => {
    async function load() {
      try {
        const data = await getReportById(id);
        setReport(data);
        setForm(buildFormState(data.extractedData));

        // Look up the reporting user's name from Firestore
        if (data.reportedBy) {
          try {
            const userSnap = await getDoc(doc(db, "users", data.reportedBy));
            if (userSnap.exists()) {
              setReporterName(userSnap.data().name || "");
            }
          } catch (err) {
            console.error("Failed to load reporter name:", err);
          }
        }
      } catch (err) {
        setError("Report not found.");
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [id]);

  function formatDate(timestamp) {
    if (!timestamp?.toDate) return "";
    return timestamp.toDate().toLocaleDateString("en-US", {
      month: "long",
      day: "numeric",
      year: "numeric",
    });
  }

  function formatTime(timestamp) {
    if (!timestamp?.toDate) return "";
    return timestamp.toDate().toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
    });
  }

  function updateField(key, value) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }

  function handleCategoryChange(value) {
    setForm((prev) => ({ 
      ...prev, 
      category: value, 
      customCategory: value === "Other" ? prev.customCategory : "" 
    }));
  }

  function updateNutrition(key, value) {
    setForm((prev) => ({
      ...prev,
      nutrition: { ...prev.nutrition, [key]: value === "" ? 0 : Number(value) },
    }));
  }

  function toggleAllergen(allergen) {
    setForm((prev) => {
      const has = prev.allergens.includes(allergen);
      return {
        ...prev,
        allergens: has
          ? prev.allergens.filter((a) => a !== allergen)
          : [...prev.allergens, allergen],
      };
    });
  }

  // Shape matches ProductExtractionResult.toReportExtractedDataMap() exactly,
  // so an approved report's extractedData always has the same structure
  // whether it came straight from Gemini or was hand-edited by admin.
  function buildExtractedDataPayload() {
    // Use custom category if "Other" is selected, otherwise use the selected category
    const finalCategory = form.category === "Other" ? form.customCategory.trim() : form.category.trim();
    
    return {
      brand: form.brand.trim(),
      productName: form.productName.trim(),
      category: finalCategory,
      size: form.size ? Number(form.size) : "",
      servingSize: form.servingSize ? Number(form.servingSize) : "",
      ingredients: form.ingredients
        .split("\n")
        .map((i) => i.trim())
        .filter(Boolean),
      allergens: form.allergens,
      nutrition: form.nutrition,
      hasNutritionData: true, // admin has now confirmed it, one way or another
      confidenceNotes: "", // resolved -- admin has reviewed, no need to keep flagging it
    };
  }

  async function handleApproveConfirm({ cprNumber, validityDate }) {
    setActionLoading(true);
    try {
      await approveReport(id, {
        extractedData: { ...buildExtractedDataPayload(), cprNumber, validityDate },
      });
      setReport((prev) => ({ ...prev, status: "Approve" }));
      setModalType(null);
    } catch (err) {
      setError("Something went wrong. Please try again.");
    } finally {
      setActionLoading(false);
    }
  }

  async function handleConfirm() {
    setActionLoading(true);
    try {
      await rejectReport(id);
      setReport((prev) => ({ ...prev, status: "Rejected" }));
      setModalType(null);
    } catch (err) {
      setError("Something went wrong. Please try again.");
      setModalType(null);
    } finally {
      setActionLoading(false);
    }
  }

  if (loading) {
    return (
      <DashboardLayout>
        <p className="page-subtitle">Loading report...</p>
      </DashboardLayout>
    );
  }

  if (error && !report) {
    return (
      <DashboardLayout>
        <p className="table-empty error">{error}</p>
      </DashboardLayout>
    );
  }

  const isResolved = report.status !== "Pending";
  const hasExtraction = report.extractedData && Object.keys(report.extractedData).length > 0;

  return (
    <DashboardLayout>
      <div className="details-header">
        <button className="back-btn" onClick={() => navigate("/reports")}>
          <FiArrowLeft /> Back to Reports
        </button>
      </div>

      <h1 className="page-title details-title">Report Details</h1>

      <div className="details-card">
        {/* ── Product identity: name, description, reporter, date ──── */}
        <div className="details-header-block">
          <h2 className="details-product">{report.productName}</h2>
          <p className="details-product-desc">{report.productDescription}</p>

          <div className="details-meta-row">
            <div className="details-meta-item">
              <span className="details-label">Reported By</span>
              <span className="details-value">
                {reporterName || report.userName || report.reportedBy}
              </span>
            </div>
            <div className="details-meta-item">
              <span className="details-label">Date Submitted</span>
              <span className="details-value">
                {formatDate(report.dateSubmitted)} · {formatTime(report.dateSubmitted)}
              </span>
            </div>
          </div>
        </div>

        {/* ── Status + submitted photos ────────────────────────────── */}
        <div className="details-status-row">
          <span className="details-label">Status</span>
          <StatusBadge status={report.status} />
        </div>

        <div className="details-photos">
          <div className="photo-box">
            <span className="photo-box-label">Front Photo</span>
            {report.frontImageUrl ? (
              <img
                src={report.frontImageUrl}
                alt="Front of product"
                onClick={() => setLightbox(report.frontImageUrl)}
              />
            ) : (
              <div className="photo-box-empty">No front photo</div>
            )}
          </div>
          <div className="photo-box">
            <span className="photo-box-label">Back Photo (Nutrition Label)</span>
            {report.backImageUrl ? (
              <img
                src={report.backImageUrl}
                alt="Back of product / nutrition label"
                onClick={() => setLightbox(report.backImageUrl)}
              />
            ) : (
              <div className="photo-box-empty">No back photo</div>
            )}
          </div>
        </div>

        {/* ── Extracted data review (editable) ─────────────────────── */}
        <div className="extraction-section">
          <h3 className="extraction-section-title">Extracted Product Data</h3>

          {!hasExtraction && (
            <p className="extraction-pending-note">
              No extraction data yet -- this may still be processing in the
              background, or extraction failed. You can fill in the fields
              below manually using the photos above.
            </p>
          )}

          {form.confidenceNotes && (
            <div className="confidence-note">
              <strong>Notes:</strong>
              <ul>
                {form.confidenceNotes
                  .split(/[.\n]/)
                  .map(note => note.trim())
                  .filter(note => note.length > 5) // Filter out very short fragments
                  .map((note, index) => (
                    <li key={index}>{note.replace(/^•\s*/, '').replace(/^\d+\.\s*/, '').replace(/^-\s*/, '')}</li>
                  ))}
              </ul>
            </div>
          )}

          <div className="field-row">
            <div className="field-group">
              <label className="field-label">Brand</label>
              <input
                className="field-input"
                value={form.brand}
                disabled={isResolved}
                onChange={(e) => updateField("brand", e.target.value)}
              />
            </div>
            <div className="field-group">
              <label className="field-label">Product Name</label>
              <input
                className="field-input"
                value={form.productName}
                disabled={isResolved}
                onChange={(e) => updateField("productName", e.target.value)}
              />
            </div>
          </div>

          <div className="field-row">
            <div className="field-group">
              <label className="field-label">Product Category</label>
              <select
                className="field-input"
                value={form.category}
                disabled={isResolved}
                onChange={(e) => handleCategoryChange(e.target.value)}
              >
                <option value="">Select category</option>
                {PRODUCT_CATEGORIES.map((cat) => (
                  <option key={cat} value={cat}>{cat}</option>
                ))}
              </select>
            </div>
            {form.category === "Other" && (
              <div className="field-group">
                <label className="field-label">Specify Category</label>
                <input
                  className="field-input"
                  value={form.customCategory}
                  disabled={isResolved}
                  placeholder="Enter custom category"
                  onChange={(e) => updateField("customCategory", e.target.value)}
                />
              </div>
            )}
          </div>

          <div className="field-row">
            <div className="field-group">
              <label className="field-label">Package Size grams (g)</label>
              <input
                className="field-input"
                type="number"
                value={form.size}
                disabled={isResolved}
                placeholder="e.g. 155"
                onChange={(e) => updateField("size", e.target.value ? Number(e.target.value) : "")}
              />
            </div>
            <div className="field-group">
              <label className="field-label">Serving Size grams (g)</label>
              <input
                className="field-input"
                type="number"
                value={form.servingSize}
                disabled={isResolved}
                placeholder="e.g. 65"
                onChange={(e) => updateField("servingSize", e.target.value ? Number(e.target.value) : "")}
              />
            </div>
          </div>

          <div className="field-group">
            <label className="field-label">Ingredients (one per line, in label order)</label>
            <textarea
              className="field-textarea"
              value={form.ingredients}
              disabled={isResolved}
              onChange={(e) => updateField("ingredients", e.target.value)}
              style={{ height: `${Math.max(150, form.ingredients.split('\n').length * 24)}px` }}
            />
          </div>

          <div className="field-group">
            <label className="field-label">Allergens</label>
            <div className="allergen-guide">
              <strong>Allergen Guide</strong>
              <table className="allergen-table">
                <thead>
                  <tr>
                    <th>Allergen Category</th>
                    <th>Derivatives & Related Ingredients</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td>Milk</td>
                    <td>Milk, dairy, cream, cheese, yogurt, butter, lactose, casein, whey</td>
                  </tr>
                  <tr>
                    <td>Eggs</td>
                    <td>Egg, albumin, ovalbumin, mayonnaise</td>
                  </tr>
                  <tr>
                    <td>Fish</td>
                    <td>Fish, anchovy, mackerel, tuna, salmon, cod, trout</td>
                  </tr>
                  <tr>
                    <td>Shellfish</td>
                    <td>Shellfish, shrimp, prawn, crab, lobster, squid, clams, mussels, oysters, scallops, octopus, crustacean</td>
                  </tr>
                  <tr>
                    <td>Tree Nuts</td>
                    <td>Nut, almond, walnut, cashew, pecan, hazelnut, pistachio, macadamia</td>
                  </tr>
                  <tr>
                    <td>Peanuts</td>
                    <td>Peanut, groundnut, arachis, mandelonas</td>
                  </tr>
                  <tr>
                    <td>Wheat</td>
                    <td>Wheat, gluten, flour, barley, rye</td>
                  </tr>
                  <tr>
                    <td>Soy</td>
                    <td>Soy, soya, soybean, tofu, tempeh, tamari, shoyu, edamame, miso, natto, okara</td>
                  </tr>
                  <tr>
                    <td>Sesame</td>
                    <td>Sesame seeds, sesame oil, tahini</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div className="allergen-grid">
              {CANONICAL_ALLERGENS.map((allergen) => {
                const checked = form.allergens.includes(allergen);
                return (
                  <label
                    key={allergen}
                    className={`allergen-chip${checked ? " checked" : ""}`}
                  >
                    <input
                      type="checkbox"
                      checked={checked}
                      disabled={isResolved}
                      onChange={() => toggleAllergen(allergen)}
                    />
                    {allergen}
                  </label>
                );
              })}
            </div>
          </div>

          <div className="field-group">
            <label className="field-label">Nutrition (per 100g)</label>
            <div className="nutrition-grid">
              {NUTRITION_FIELDS.map(({ key, label, unit }) => (
                <div className="field-group" key={key}>
                  <label className="field-label">
                    {label} <span className="nutrition-unit">({unit})</span>
                  </label>
                  <input
                    className="field-input"
                    type="number"
                    step="any"
                    value={form.nutrition[key]}
                    disabled={isResolved}
                    onChange={(e) => updateNutrition(key, e.target.value)}
                  />
                </div>
              ))}
            </div>
          </div>
        </div>

        {!isResolved && (
          <div className="details-actions">
            <button
              className="reject-btn"
              onClick={() => setModalType("reject")}
            >
              Reject
            </button>
            <button
              className="approve-btn"
              disabled={
                !form.productName.trim() || 
                !form.category || 
                (form.category === "Other" && !form.customCategory.trim())
              }
              title={
                (!form.productName.trim() || !form.category || (form.category === "Other" && !form.customCategory.trim()))
                  ? "Product Name and Product Category are required before approving"
                  : undefined
              }
              onClick={() => setModalType("approve")}
            >
              Approve
            </button>
          </div>
        )}

        {error && <p className="form-error" style={{ marginTop: 16 }}>{error}</p>}
      </div>

      {lightbox && (
        <div
          className="modal-overlay"
          onClick={() => setLightbox(null)}
          style={{ cursor: "zoom-out" }}
        >
          <img
            src={lightbox}
            alt="Full size"
            style={{ maxWidth: "90vw", maxHeight: "90vh", borderRadius: 8 }}
          />
        </div>
      )}

      {modalType === "approve" && (
        <FdaVerificationModal
          onConfirm={handleApproveConfirm}
          onClose={() => setModalType(null)}
          loading={actionLoading}
        />
      )}

      {modalType === "reject" && (
        <ConfirmModal
          type={modalType}
          onConfirm={handleConfirm}
          onClose={() => setModalType(null)}
          loading={actionLoading}
        />
      )}
    </DashboardLayout>
  );
}
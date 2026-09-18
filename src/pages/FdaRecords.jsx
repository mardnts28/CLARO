import { useState, useEffect, useMemo } from "react";
import DashboardLayout from "../components/DashboardLayout";
import FdaVerificationModal from "../components/FdaVerificationModal";
import {
  getAllProducts,
  updateProductFdaRecord,
  getProductCprExpiration,
  getCprExpirationSummary,
} from "../services/fdaRecordService";
import {
  FiSearch,
  FiX,
  FiShield,
  FiCheckCircle,
  FiAlertCircle,
  FiEdit3,
  FiUploadCloud,
  FiPackage,
  FiClock,
  FiAlertTriangle,
} from "react-icons/fi";
import "./FdaRecords.css";
import "./Reports.css";
import "./Dashboard.css";

function formatCategoryName(category) {
  if (!category) return "—";
  return category
    .split("_")
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}

export default function FdaRecords() {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [activeTab, setActiveTab] = useState("all"); // "all" | "attention" | "verified" | "unverified"
  const [selectedProduct, setSelectedProduct] = useState(null);
  const [modalLoading, setModalLoading] = useState(false);
  const [lightbox, setLightbox] = useState(null);
  const [successMessage, setSuccessMessage] = useState("");
  const [bannerDismissed, setBannerDismissed] = useState(false);

  useEffect(() => {
    async function load() {
      try {
        const data = await getAllProducts();
        setProducts(data);
      } catch (err) {
        console.error("PRODUCTS LOAD ERROR:", err);
        setError("Failed to load products. Please try again.");
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  function formatValidityDate(raw) {
    if (!raw) return "—";
    if (raw?.toDate) {
      return raw.toDate().toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
        year: "numeric",
      });
    }
    const d = new Date(raw);
    if (isNaN(d.getTime())) return String(raw);
    return d.toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  }

  // Calculate CPR expiration summary across all products (60 days threshold)
  const expirationSummary = useMemo(
    () => getCprExpirationSummary(products, 60),
    [products]
  );

  // Filter products by search and tab
  const filteredProducts = useMemo(() => {
    const q = search.toLowerCase().trim();

    return products
      .filter((p) => {
        const name = (p.product_name || p.name || "").toLowerCase();
        const brand = (p.brand || "").toLowerCase();
        const cpr = (p.cpr_number || "").toLowerCase();

        const matchesSearch =
          !q || name.includes(q) || brand.includes(q) || cpr.includes(q);

        if (!matchesSearch) return false;

        const exp = getProductCprExpiration(p, 60);

        if (activeTab === "attention") {
          return exp.isExpired || exp.isExpiringSoon;
        }
        if (activeTab === "verified") {
          return exp.status === "verified";
        }
        if (activeTab === "unverified") {
          return exp.status === "needs_cpr";
        }

        return true;
      })
      .sort((a, b) => {
        // If viewing attention tab, order by most urgent first (expired or earliest expiry)
        if (activeTab === "attention") {
          const expA = getProductCprExpiration(a, 60);
          const expB = getProductCprExpiration(b, 60);
          return (expA.daysLeft ?? 9999) - (expB.daysLeft ?? 9999);
        }
        return 0;
      });
  }, [products, search, activeTab]);

  // Handle updating FDA status with OCR/screenshot
  async function handleConfirmFdaUpdate({
    cprNumber,
    validityDate,
    screenshotFile,
  }) {
    if (!selectedProduct) return;
    setModalLoading(true);

    try {
      const updated = await updateProductFdaRecord(selectedProduct.id, {
        cprNumber,
        validityDate,
        screenshotFile,
        productName: selectedProduct.product_name || selectedProduct.name || "",
      });

      // Update local state so UI updates immediately
      setProducts((prev) =>
        prev.map((item) =>
          item.id === selectedProduct.id
            ? {
                ...item,
                ...updated,
                cpr_number: updated.cpr_number,
                validity_date: updated.validity_date,
                registration_status: updated.registration_status,
                fda_screenshot_url:
                  updated.fda_screenshot_url || item.fda_screenshot_url,
              }
            : item
        )
      );

      setSuccessMessage(
        `Successfully updated FDA record for "${selectedProduct.product_name || selectedProduct.name || "product"}".`
      );
      setSelectedProduct(null);

      setTimeout(() => setSuccessMessage(""), 5000);
    } catch (err) {
      console.error("UPDATE FDA RECORD ERROR:", err);
      throw err;
    } finally {
      setModalLoading(false);
    }
  }

  return (
    <DashboardLayout>
      <h1 className="page-title">FDA Records</h1>

      {/* Success Notification */}
      {successMessage && (
        <div className="fda-success-banner" role="alert">
          <FiCheckCircle />
          <span>{successMessage}</span>
        </div>
      )}

      {/* ── Slim Callout Alert Banner (Stripe / GitHub style) ───── */}
      {expirationSummary.hasAttentionNeeded && !bannerDismissed && (
        <div className="fda-callout-banner" role="alert">
          <div className="fda-callout-main">
            <span className="fda-callout-icon">
              <FiAlertTriangle />
            </span>
            <span className="fda-callout-text">
              <strong>
                {expirationSummary.attentionCount} product{expirationSummary.attentionCount === 1 ? "" : "s"}
              </strong>{" "}
              {expirationSummary.expired.length > 0 && expirationSummary.expiringSoon.length > 0 ? (
                <>({expirationSummary.expired.length} expired, {expirationSummary.expiringSoon.length} expiring soon)</>
              ) : expirationSummary.expired.length > 0 ? (
                <>(CPR registration expired)</>
              ) : (
                <>(expiring within 60 days)</>
              )}{" "}
              require renewal from the FDA Verification Portal.
            </span>
          </div>

          <div className="fda-callout-actions">
            {activeTab !== "attention" && (
              <button
                type="button"
                className="fda-callout-btn"
                onClick={() => setActiveTab("attention")}
              >
                View Products &rarr;
              </button>
            )}
            <button
              type="button"
              className="fda-callout-close"
              onClick={() => setBannerDismissed(true)}
              aria-label="Dismiss notification"
              title="Dismiss notification"
            >
              <FiX />
            </button>
          </div>
        </div>
      )}

      {/* ── Status Tabs ──────────────────────────────────────────── */}
      <div className="fda-tabs">
        <button
          className={`fda-tab-btn ${activeTab === "all" ? "active" : ""}`}
          onClick={() => setActiveTab("all")}
        >
          All Products
          <span className="fda-tab-count">{products.length}</span>
        </button>

        {expirationSummary.attentionCount > 0 && (
          <button
            className={`fda-tab-btn attention-tab ${activeTab === "attention" ? "active" : ""}`}
            onClick={() => setActiveTab("attention")}
          >
            <FiClock /> Needs Attention
            <span className="fda-tab-count count-attention">
              {expirationSummary.attentionCount}
            </span>
          </button>
        )}

        <button
          className={`fda-tab-btn ${activeTab === "verified" ? "active" : ""}`}
          onClick={() => setActiveTab("verified")}
        >
          <FiCheckCircle /> Verified
          <span className="fda-tab-count">
            {expirationSummary.verified.length}
          </span>
        </button>

        <button
          className={`fda-tab-btn ${activeTab === "unverified" ? "active" : ""}`}
          onClick={() => setActiveTab("unverified")}
        >
          <FiAlertCircle /> Needs CPR
          <span className="fda-tab-count">
            {expirationSummary.needsCpr.length}
          </span>
        </button>
      </div>

      {/* ── Search Toolbar ───────────────────────────────────────── */}
      <div className="reports-toolbar">
        <div className="search-box">
          <input
            type="text"
            placeholder="Search by product name, brand, or CPR number…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <FiSearch className="search-icon" />
        </div>
      </div>

      {/* ── Products Table ───────────────────────────────────────── */}
      <div className="reports-table-card">
        {loading ? (
          <p className="table-empty">Loading products…</p>
        ) : error ? (
          <p className="table-empty error">{error}</p>
        ) : filteredProducts.length === 0 ? (
          <div className="fda-empty-state">
            <FiShield className="fda-empty-icon" />
            <p className="fda-empty-title">No products found</p>
            <p className="fda-empty-sub">
              {search
                ? "No products matched your search filter."
                : activeTab === "attention"
                ? "No products currently need CPR renewal attention."
                : "No products currently in this tab."}
            </p>
          </div>
        ) : (
          <div className="reports-table-scroll">
            <table className="reports-table">
              <thead>
                <tr>
                  <th>Product</th>
                  <th>Category</th>
                  <th>CPR Number</th>
                  <th>Validity Date</th>
                  <th>Status</th>
                  <th>FDA Screenshot</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {filteredProducts.map((p) => {
                  const productName = p.product_name || p.name || "—";
                  const brand = p.brand || "";
                  const category = formatCategoryName(
                    p.product_category || p.category
                  );
                  const cprNumber = p.cpr_number || "";
                  const validityDate = formatValidityDate(p.validity_date);
                  const isVerified = Boolean(p.registration_status || cprNumber);
                  const screenshotUrl = p.fda_screenshot_url || "";
                  const imageUrl = p.imageURL || p.imageUrl || "";
                  const exp = getProductCprExpiration(p, 60);

                  return (
                    <tr key={p.id}>
                      {/* Product Thumbnail & Details */}
                      <td>
                        <div className="fda-product-cell">
                          {imageUrl ? (
                            <img
                              src={imageUrl}
                              alt={productName}
                              className="fda-product-thumb"
                            />
                          ) : (
                            <div className="fda-product-placeholder">
                              <FiPackage />
                            </div>
                          )}
                          <div className="fda-product-info">
                            <span className="fda-product-title">
                              {productName}
                            </span>
                            {brand && (
                              <span className="fda-product-brand">
                                {brand}
                              </span>
                            )}
                          </div>
                        </div>
                      </td>

                      {/* Category */}
                      <td>
                        <span className="fda-category-badge">{category}</span>
                      </td>

                      {/* CPR Number */}
                      <td>
                        {cprNumber ? (
                          <span className="fda-cpr-badge">{cprNumber}</span>
                        ) : (
                          <span className="fda-cpr-empty">No CPR</span>
                        )}
                      </td>

                      {/* Validity Date with relative countdown/expiry */}
                      <td className="date-cell">
                        <span>{validityDate}</span>
                        {exp.status === "expired" && (
                          <span className="fda-date-sub fda-date-expired">
                            Expired {exp.daysAgo}d ago
                          </span>
                        )}
                        {exp.status === "expiring_soon" && (
                          <span className="fda-date-sub fda-date-expiring">
                            {exp.daysLeft === 0
                              ? "Expires today"
                              : `${exp.daysLeft}d remaining`}
                          </span>
                        )}
                      </td>

                      {/* Status */}
                      <td>
                        {exp.status === "expired" ? (
                          <span className="fda-status-badge expired">
                            <FiAlertTriangle /> Expired
                          </span>
                        ) : exp.status === "expiring_soon" ? (
                          <span className="fda-status-badge expiring">
                            <FiClock /> Expiring Soon
                          </span>
                        ) : exp.status === "verified" ? (
                          <span className="fda-status-badge verified">
                            <FiCheckCircle /> Verified
                          </span>
                        ) : (
                          <span className="fda-status-badge unverified">
                            <FiAlertCircle /> Needs CPR
                          </span>
                        )}
                      </td>

                      {/* FDA Screenshot */}
                      <td>
                        {screenshotUrl ? (
                          <button
                            className="fda-thumb-btn"
                            onClick={() => setLightbox(screenshotUrl)}
                            title="Click to view full screenshot"
                          >
                            <img
                              src={screenshotUrl}
                              alt="FDA screenshot"
                              className="fda-thumb"
                            />
                          </button>
                        ) : (
                          <span className="fda-no-screenshot">—</span>
                        )}
                      </td>

                      {/* Action */}
                      <td>
                        {exp.status === "expired" ? (
                          <button
                            className="fda-update-btn btn-expired"
                            onClick={() => setSelectedProduct(p)}
                            title="CPR expired — click to renew with a new FDA screenshot"
                          >
                            <FiAlertTriangle /> Renew CPR
                          </button>
                        ) : exp.status === "expiring_soon" ? (
                          <button
                            className="fda-update-btn btn-renew"
                            onClick={() => setSelectedProduct(p)}
                            title="CPR expiring soon — click to renew with a new FDA screenshot"
                          >
                            <FiClock /> Renew CPR
                          </button>
                        ) : isVerified ? (
                          <button
                            className="fda-update-btn btn-outline"
                            onClick={() => setSelectedProduct(p)}
                            title="Update FDA portal record"
                          >
                            <FiEdit3 /> Update FDA
                          </button>
                        ) : (
                          <button
                            className="fda-update-btn btn-primary"
                            onClick={() => setSelectedProduct(p)}
                            title="Verify and attach FDA registration"
                          >
                            <FiUploadCloud /> Verify FDA
                          </button>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* ── Lightbox for full screenshot ─────────────────────────── */}
      {lightbox && (
        <div
          className="modal-overlay fda-lightbox-overlay"
          onClick={() => setLightbox(null)}
          style={{ cursor: "zoom-out" }}
        >
          <button
            className="fda-lightbox-close"
            onClick={() => setLightbox(null)}
          >
            <FiX />
          </button>
          <img
            src={lightbox}
            alt="FDA screenshot full size"
            className="fda-lightbox-img"
            onClick={(e) => e.stopPropagation()}
          />
        </div>
      )}

      {/* ── OCR Verification / Update Modal ──────────────────────── */}
      {selectedProduct && (
        <FdaVerificationModal
          productName={
            selectedProduct.product_name ||
            selectedProduct.name ||
            selectedProduct.brand ||
            "Product"
          }
          brand={selectedProduct.brand || ""}
          onConfirm={handleConfirmFdaUpdate}
          onClose={() => setSelectedProduct(null)}
          loading={modalLoading}
        />
      )}
    </DashboardLayout>
  );
}

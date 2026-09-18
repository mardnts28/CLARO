import { useState, useRef } from "react";
import {
  FiX,
  FiCheckCircle,
  FiUploadCloud,
  FiAlertTriangle,
  FiAlertCircle,
  FiEdit3,
} from "react-icons/fi";
import { extractFdaDataWithGemini } from "../services/fdaRecordService";
import "./ConfirmModal.css";
import "./FdaVerificationModal.css";

// Stage 1: Admin uploads an FDA portal screenshot (or chooses manual entry).
// Stage 2: Gemini OCR extracts CPR number, validity date & checks product alignment;
//          admin can review, verify, or correct the details.
// Confirming stage 2 triggers onConfirm({ cprNumber, validityDate, screenshotFile }).
export default function FdaVerificationModal({
  productName,
  brand,
  onConfirm,
  onClose,
  loading,
}) {
  const [stage, setStage] = useState("upload"); // "upload" | "scanning" | "review"
  const [screenshotFile, setScreenshotFile] = useState(null);
  const [previewUrl, setPreviewUrl] = useState(null);
  const [dragOver, setDragOver] = useState(false);
  const [lowConfidence, setLowConfidence] = useState(false);
  const [alignmentResult, setAlignmentResult] = useState(null);
  const [errors, setErrors] = useState({});

  // Stage 2 — editable fields
  const [cprNumber, setCprNumber] = useState("");
  const [validityDate, setValidityDate] = useState("");

  const MAX_FILE_SIZE_MB = 10;
  const MAX_FILE_SIZE_BYTES = MAX_FILE_SIZE_MB * 1024 * 1024;

  const fileInputRef = useRef(null);

  // ── File selection ──────────────────────────────────────────────────────
  function handleFile(file) {
    if (!file) return;
    if (!file.type.startsWith("image/")) {
      setErrors({ screenshot: "Please upload a valid image file (PNG, JPG, WEBP)." });
      return;
    }
    if (file.size > MAX_FILE_SIZE_BYTES) {
      const sizeInMb = (file.size / (1024 * 1024)).toFixed(1);
      setErrors({
        screenshot: `Screenshot is ${sizeInMb} MB. Please upload an image under ${MAX_FILE_SIZE_MB} MB.`,
      });
      return;
    }
    setErrors({});
    setScreenshotFile(file);
    setPreviewUrl(URL.createObjectURL(file));
  }

  function handleInputChange(e) {
    const file = e.target.files?.[0];
    if (file) {
      handleFile(file);
    }
    e.target.value = "";
  }

  function handleDrop(e) {
    e.preventDefault();
    setDragOver(false);
    handleFile(e.dataTransfer.files[0]);
  }

  // ── OCR scan with Product Alignment Check ───────────────────────────────
  async function handleScan() {
    if (!screenshotFile) {
      setErrors({ screenshot: "Please upload an FDA verification screenshot first." });
      return;
    }

    setErrors({});
    setStage("scanning");

    try {
      const result = await extractFdaDataWithGemini(screenshotFile, {
        name: productName,
        brand: brand,
      });

      setCprNumber(result.cprNumber || "");
      setValidityDate(result.validityDate || "");
      setLowConfidence(Boolean(result.lowConfidence));
      setAlignmentResult({
        aligns: result.aligns !== false,
        detectedProduct: result.detectedProduct || "",
        mismatchReason: result.mismatchReason || "",
      });

      setStage("review");
    } catch (err) {
      setErrors({
        form:
          err.message ||
          "Could not scan the screenshot. Please try again or enter details manually.",
      });
      setStage("upload");
    }
  }

  // ── Validation for Review Stage ──────────────────────────────────────────
  function validateReview() {
    const newErrors = {};
    if (!cprNumber.trim()) {
      newErrors.cprNumber = "CPR number is required.";
    }
    if (!validityDate.trim()) {
      newErrors.validityDate = "Validity date is required.";
    }
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  }

  // ── Final confirm ────────────────────────────────────────────────────────
  async function handleSubmit(e) {
    e?.preventDefault();
    if (!validateReview()) return;

    try {
      await onConfirm({
        cprNumber: cprNumber.trim(),
        validityDate,
        screenshotFile,
      });
    } catch (err) {
      setErrors({
        form: err.message || "Failed to confirm FDA verification. Please try again.",
      });
    }
  }

  // ── Restart / Upload different image ────────────────────────────────────
  function handleRescan() {
    setStage("upload");
    setScreenshotFile(null);
    setPreviewUrl(null);
    setCprNumber("");
    setValidityDate("");
    setAlignmentResult(null);
    setErrors({});
    setLowConfidence(false);
    if (fileInputRef.current) {
      fileInputRef.current.value = "";
    }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div
        className="modal-box fda-modal-box"
        onClick={(e) => e.stopPropagation()}
      >
        <button className="modal-close" onClick={onClose} disabled={loading}>
          <FiX />
        </button>

        <div className="modal-icon icon-approve">
          <FiCheckCircle />
        </div>

        <h3 className="modal-title">
          {productName ? "Update FDA Record" : "FDA Verification"}
        </h3>

        {/* ── STAGE: upload ─────────────────────────────────────────────── */}
        {(stage === "upload" || stage === "scanning") && (
          <>
            <p className="fda-verification-note">
              {productName ? (
                <>
                  Verifying <strong>{productName}</strong>. Take a screenshot of its row from the{" "}
                  <a
                    href="https://verification.fda.gov.ph/"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    FDA Philippine Verification Portal
                  </a>
                  , then upload it below. Gemini OCR will verify the product match and extract the CPR number and validity date automatically.
                </>
              ) : (
                <>
                  Take a screenshot from the{" "}
                  <a
                    href="https://verification.fda.gov.ph/"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    FDA Philippine Verification Portal
                  </a>
                  , then upload it below. Gemini will extract the CPR number and
                  validity date automatically.
                </>
              )}
            </p>

            {/* Drop zone */}
            <div
              className={`fda-dropzone${dragOver ? " fda-dropzone-active" : ""}${screenshotFile ? " fda-dropzone-has-file" : ""}${errors.screenshot ? " input-error" : ""}`}
              onClick={() => fileInputRef.current?.click()}
              onDragOver={(e) => {
                e.preventDefault();
                setDragOver(true);
              }}
              onDragLeave={() => setDragOver(false)}
              onDrop={handleDrop}
            >
              {screenshotFile ? (
                <img
                  src={previewUrl}
                  alt="Screenshot preview"
                  className="fda-preview-img"
                />
              ) : (
                <>
                  <FiUploadCloud className="fda-upload-icon" />
                  <p className="fda-dropzone-text">
                    Drag &amp; drop or <span className="fda-dropzone-link">click to upload</span>
                  </p>
                  <p className="fda-dropzone-sub">PNG, JPG, WEBP (Max 10 MB)</p>
                </>
              )}
            </div>

            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              className="fda-hidden-input"
              onChange={handleInputChange}
            />

            {screenshotFile && (
              <p className="fda-filename">{screenshotFile.name}</p>
            )}

            {errors.screenshot && (
              <span className="field-error fda-center-error">{errors.screenshot}</span>
            )}

            {errors.form && (
              <div className="form-error" role="alert">
                <FiAlertCircle className="form-error-icon" />
                <div>
                  <span>{errors.form}</span>
                  <button
                    type="button"
                    className="fda-manual-fallback-btn"
                    onClick={() => {
                      setErrors({});
                      setStage("review");
                    }}
                  >
                    <FiEdit3 /> Enter CPR Details Manually
                  </button>
                </div>
              </div>
            )}

            <button
              type="button"
              className="modal-confirm-btn btn-approve fda-scan-btn"
              onClick={handleScan}
              disabled={stage === "scanning"}
            >
              {stage === "scanning" ? (
                <span className="fda-scanning-pulse">Verifying &amp; Scanning…</span>
              ) : (
                "Scan Screenshot"
              )}
            </button>

            {/* Manual entry fallback option */}
            <div className="fda-manual-option">
              <button
                type="button"
                className="fda-manual-link"
                onClick={() => {
                  setErrors({});
                  setStage("review");
                }}
              >
                Or enter CPR details manually
              </button>
            </div>
          </>
        )}

        {/* ── STAGE: review ─────────────────────────────────────────────── */}
        {stage === "review" && (
          <form onSubmit={handleSubmit} noValidate>
            {/* Thumbnail reference */}
            <div className="fda-review-thumb-wrap">
              {previewUrl && (
                <img
                  src={previewUrl}
                  alt="FDA screenshot"
                  className="fda-review-thumb"
                />
              )}
              <button
                className="fda-rescan-link"
                type="button"
                onClick={handleRescan}
              >
                Upload different screenshot
              </button>
            </div>

            {/* Product Mismatch Warning */}
            {alignmentResult && alignmentResult.aligns === false && (
              <div className="fda-mismatch-warning" role="alert">
                <div className="fda-mismatch-title">
                  <FiAlertTriangle className="fda-mismatch-icon" />
                  <span>Product Mismatch Detected</span>
                </div>
                <p className="fda-mismatch-desc">
                  {alignmentResult.mismatchReason ||
                    `The uploaded screenshot does not appear to match "${productName}".`}
                </p>
                {alignmentResult.detectedProduct && (
                  <div className="fda-mismatch-detected">
                    <span className="fda-mismatch-label">Found in screenshot:</span>
                    <strong className="fda-mismatch-val">
                      {alignmentResult.detectedProduct}
                    </strong>
                  </div>
                )}
                <div className="fda-mismatch-actions">
                  <button
                    type="button"
                    className="fda-mismatch-change-btn"
                    onClick={handleRescan}
                  >
                    Upload Correct Screenshot
                  </button>
                  <span className="fda-mismatch-or">or proceed if correct</span>
                </div>
              </div>
            )}

            {/* Product Match Success Badge */}
            {alignmentResult && alignmentResult.aligns === true && alignmentResult.detectedProduct && (
              <div className="fda-match-badge">
                <FiCheckCircle className="fda-match-icon" />
                <span>
                  Portal match: <strong>{alignmentResult.detectedProduct}</strong>
                </span>
              </div>
            )}

            {lowConfidence && (
              <div className="fda-confidence-warning">
                <FiAlertTriangle />
                <span>Auto-filled — OCR confidence was low. Please verify the values below.</span>
              </div>
            )}

            <div className="fda-field-group">
              <label className="field-label">CPR Number</label>
              <input
                className={`field-input ${errors.cprNumber ? "input-error" : ""}`}
                value={cprNumber}
                placeholder="e.g. FR-4000013795050"
                onChange={(e) => {
                  setCprNumber(e.target.value);
                  if (errors.cprNumber) {
                    setErrors((prev) => ({ ...prev, cprNumber: "" }));
                  }
                }}
                disabled={loading}
              />
              {errors.cprNumber && (
                <span className="field-error">{errors.cprNumber}</span>
              )}
            </div>

            <div className="fda-field-group">
              <label className="field-label">Validity Date</label>
              <input
                className={`field-input ${errors.validityDate ? "input-error" : ""}`}
                type="date"
                value={validityDate}
                onChange={(e) => {
                  setValidityDate(e.target.value);
                  if (errors.validityDate) {
                    setErrors((prev) => ({ ...prev, validityDate: "" }));
                  }
                }}
                disabled={loading}
              />
              {errors.validityDate && (
                <span className="field-error">{errors.validityDate}</span>
              )}
            </div>

            {errors.form && (
              <div className="form-error" role="alert">
                <FiAlertCircle className="form-error-icon" />
                <span>{errors.form}</span>
              </div>
            )}

            <button
              type="submit"
              className="modal-confirm-btn btn-approve"
              disabled={loading}
            >
              {loading ? "Please wait…" : "Confirm & Save FDA Record"}
            </button>
          </form>
        )}
      </div>
    </div>
  );
}

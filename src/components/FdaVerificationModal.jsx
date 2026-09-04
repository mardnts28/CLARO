import { useState } from "react";
import { FiX, FiCheckCircle } from "react-icons/fi";
import "./ConfirmModal.css";
import "./FdaVerificationModal.css";

// Shown when admin clicks "Approve" -- collects the CPR number and
// validity date for FDA verification. Confirming here triggers
// approveReport() -- there's no separate yes/no step after this, since
// filling in these two required fields already serves as the admin's
// explicit confirmation.
export default function FdaVerificationModal({ onConfirm, onClose, loading }) {
  const [cprNumber, setCprNumber] = useState("");
  const [validityDate, setValidityDate] = useState("");
  const [touched, setTouched] = useState(false);

  const cprValid = cprNumber.trim().length > 0;
  const dateValid = validityDate.trim().length > 0;
  const canSubmit = cprValid && dateValid;

  function handleSubmit() {
    setTouched(true);
    if (!canSubmit) return;
    onConfirm({ cprNumber: cprNumber.trim(), validityDate });
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-box fda-modal-box" onClick={(e) => e.stopPropagation()}>
        <button className="modal-close" onClick={onClose}>
          <FiX />
        </button>

        <div className="modal-icon icon-approve">
          <FiCheckCircle />
        </div>

        <h3 className="modal-title">FDA Verification</h3>

        <p className="fda-verification-note">
          Verify the product is FDA registered through the{" "}
          <a
            href="https://verification.fda.gov.ph/"
            target="_blank"
            rel="noopener noreferrer"
          >
            FDA Philippine Verification Portal
          </a>
          .
        </p>

        <div className="fda-field-group">
          <label className="field-label">CPR Number</label>
          <input
            className="field-input"
            value={cprNumber}
            placeholder="e.g. FR-12345"
            onChange={(e) => setCprNumber(e.target.value)}
            disabled={loading}
          />
          {touched && !cprValid && (
            <span className="fda-field-error">CPR number is required.</span>
          )}
        </div>

        <div className="fda-field-group">
          <label className="field-label">Validity Date</label>
          <input
            className="field-input"
            type="date"
            value={validityDate}
            onChange={(e) => setValidityDate(e.target.value)}
            disabled={loading}
          />
          {touched && !dateValid && (
            <span className="fda-field-error">Validity date is required.</span>
          )}
        </div>

        <button
          className="modal-confirm-btn btn-approve"
          onClick={handleSubmit}
          disabled={loading}
        >
          {loading ? "Please wait..." : "Confirm"}
        </button>
      </div>
    </div>
  );
}
import { useState } from "react";
import { FiX, FiCheckCircle, FiXCircle } from "react-icons/fi";
import "./ConfirmModal.css";

const MAX_REASON_LENGTH = 50;

const PRESET_REJECTION_REASONS = [
  "I need a clearer picture.",
  "Blurry or unreadable label.",
  "Missing nutrition facts or ingredients.",
  "Duplicate product submission.",
  "Incorrect product name or brand.",
  "Expired or invalid CPR details.",
  "Non-food item or irrelevant photo.",
];

export default function ConfirmModal({
  type, // "approve" | "reject"
  onConfirm,
  onClose,
  loading,
}) {
  const isApprove = type === "approve";
  const [reason, setReason] = useState("");
  const [selectedPreset, setSelectedPreset] = useState("");

  function handlePresetChange(e) {
    const val = e.target.value;
    setSelectedPreset(val);
    if (val && val !== "custom") {
      setReason(val.slice(0, MAX_REASON_LENGTH));
    } else if (val === "custom") {
      setReason("");
    }
  }

  function handleReasonChange(e) {
    const val = e.target.value.slice(0, MAX_REASON_LENGTH);
    setReason(val);
    if (PRESET_REJECTION_REASONS.includes(val)) {
      setSelectedPreset(val);
    } else if (val.trim()) {
      setSelectedPreset("custom");
    } else {
      setSelectedPreset("");
    }
  }

  function handleSubmit(e) {
    if (e) e.preventDefault();
    if (!isApprove && !reason.trim()) return;
    onConfirm(reason.trim());
  }

  const isConfirmDisabled = loading || (!isApprove && !reason.trim());

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-box" onClick={(e) => e.stopPropagation()}>
        <button className="modal-close" onClick={onClose} aria-label="Close modal">
          <FiX />
        </button>

        <div className={`modal-icon ${isApprove ? "icon-approve" : "icon-reject"}`}>
          {isApprove ? <FiCheckCircle /> : <FiXCircle />}
        </div>

        <h3 className="modal-title">
          {isApprove ? "Report Approved" : "Reject Report"}
        </h3>
        <p className="modal-desc">
          {isApprove
            ? "You have approved this report."
            : "Please select or enter a reason for rejecting this report."}
        </p>

        {!isApprove && (
          <form onSubmit={handleSubmit} className="modal-reason-group">
            <div className="modal-reason-select-wrapper">
              <label htmlFor="rejection-preset-select" className="modal-reason-label">
                Select Common Reason
              </label>
              <select
                id="rejection-preset-select"
                className="modal-reason-select"
                value={selectedPreset}
                onChange={handlePresetChange}
                disabled={loading}
              >
                <option value="">-- Choose a preset reason or type below --</option>
                {PRESET_REJECTION_REASONS.map((preset) => (
                  <option key={preset} value={preset}>
                    {preset}
                  </option>
                ))}
                <option value="custom">Other / Custom reason...</option>
              </select>
            </div>

            <div className="modal-reason-header">
              <label htmlFor="rejection-reason" className="modal-reason-label">
                Reason for Rejection <span className="modal-required-star">*</span>
              </label>
              <span
                className={`modal-char-counter ${
                  reason.length >= MAX_REASON_LENGTH ? "limit-reached" : ""
                }`}
              >
                {reason.length}/{MAX_REASON_LENGTH}
              </span>
            </div>
            <input
              id="rejection-reason"
              type="text"
              className="modal-reason-input"
              placeholder="Select from above or type your reason..."
              value={reason}
              maxLength={MAX_REASON_LENGTH}
              onChange={handleReasonChange}
              disabled={loading}
              autoFocus
            />
          </form>
        )}

        <button
          className={`modal-confirm-btn ${isApprove ? "btn-approve" : "btn-reject"}`}
          onClick={handleSubmit}
          disabled={isConfirmDisabled}
        >
          {loading
            ? "Please wait..."
            : isApprove
            ? "Confirm Approval"
            : "Confirm Rejection"}
        </button>
      </div>
    </div>
  );
}
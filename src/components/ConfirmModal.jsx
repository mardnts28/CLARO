import { FiX, FiCheckCircle, FiXCircle } from "react-icons/fi";
import "./ConfirmModal.css";

export default function ConfirmModal({
  type, // "approve" | "reject"
  onConfirm,
  onClose,
  loading,
}) {
  const isApprove = type === "approve";

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-box" onClick={(e) => e.stopPropagation()}>
        <button className="modal-close" onClick={onClose}>
          <FiX />
        </button>

        <div className={`modal-icon ${isApprove ? "icon-approve" : "icon-reject"}`}>
          {isApprove ? <FiCheckCircle /> : <FiXCircle />}
        </div>

        <h3 className="modal-title">
          {isApprove ? "Report Approved" : "Report Rejected"}
        </h3>
        <p className="modal-desc">
          {isApprove
            ? "You have approved this report."
            : "You have rejected this report."}
        </p>

        <button
          className={`modal-confirm-btn ${isApprove ? "btn-approve" : "btn-reject"}`}
          onClick={onConfirm}
          disabled={loading}
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
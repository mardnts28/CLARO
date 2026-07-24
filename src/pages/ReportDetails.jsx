import { useState, useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import DashboardLayout from "../components/DashboardLayout";
import ConfirmModal from "../components/ConfirmModal";
import { getReportById, approveReport, rejectReport } from "../services/reportService";
import { FiArrowLeft } from "react-icons/fi";
import "./ReportDetails.css";

function StatusBadge({ status }) {
  const map = {
    Approve: "badge badge-approved",
    Pending: "badge badge-pending",
    Rejected: "badge badge-rejected",
  };
  return <span className={map[status] || "badge"}>{status}</span>;
}

export default function ReportDetails() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [report, setReport] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [modalType, setModalType] = useState(null); // "approve" | "reject" | null
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    async function load() {
      try {
        const data = await getReportById(id);
        setReport(data);
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

  async function handleConfirm() {
    setActionLoading(true);
    try {
      if (modalType === "approve") {
        await approveReport(id);
        setReport((prev) => ({ ...prev, status: "Approve" }));
      } else {
        await rejectReport(id);
        setReport((prev) => ({ ...prev, status: "Rejected" }));
      }
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

  return (
    <DashboardLayout>
      <div className="details-header">
        <h1 className="page-title">Report Details</h1>
        <button className="back-btn" onClick={() => navigate("/reports")}>
          <FiArrowLeft /> Back to Reports
        </button>
      </div>

      <div className="details-card">
        <h2 className="details-product">{report.productName}</h2>
        <p className="details-product-desc">{report.productDescription}</p>

        <div className="details-row">
          <span className="details-label">Reported By:</span>
          <span className="details-value">{report.reportedBy}</span>
        </div>

        <div className="details-row">
          <span className="details-label">Date Submitted:</span>
          <span className="details-value">
            {formatDate(report.dateSubmitted)}
            <br />
            {formatTime(report.dateSubmitted)}
          </span>
        </div>

        <div className="details-row">
          <span className="details-label">Status</span>
        </div>
        <StatusBadge status={report.status} />

        {!isResolved && (
          <div className="details-actions">
            <button
              className="reject-btn"
              onClick={() => setModalType("reject")}
            >
              Reject Report
            </button>
            <button
              className="approve-btn"
              onClick={() => setModalType("approve")}
            >
              Approve Report
            </button>
          </div>
        )}

        {error && <p className="form-error" style={{ marginTop: 16 }}>{error}</p>}
      </div>

      {modalType && (
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
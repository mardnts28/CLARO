import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import DashboardLayout from "../components/DashboardLayout";
import { getDashboardStats, getRecentReports } from "../services/reportService";
import { FiClipboard } from "react-icons/fi";
import "./Dashboard.css";

function StatusBadge({ status }) {
  const map = {
    Approve: "badge badge-approved",
    Pending: "badge badge-pending",
    Rejected: "badge badge-rejected",
  };
  return <span className={map[status] || "badge"}>{status}</span>;
}

export default function Dashboard() {
  const navigate = useNavigate();
  const [stats, setStats] = useState({ totalReports: 0, pendingReports: 0 });
  const [recentReports, setRecentReports] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    async function load() {
      try {
        const [statsData, recentData] = await Promise.all([
          getDashboardStats(),
          getRecentReports(5),
        ]);
        setStats(statsData);
        setRecentReports(recentData);
      } catch (err) {
        console.error("DASHBOARD LOAD ERROR:", err);
        setError("Failed to load dashboard data.");
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  function formatDate(timestamp) {
    if (!timestamp?.toDate) return "—";
    return timestamp.toDate().toLocaleDateString("en-US", {
      month: "short",
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

  return (
    <DashboardLayout>
      <h1 className="page-title">Dashboard</h1>
      <p className="page-subtitle">Welcome back, Admin!</p>

      {error && <p className="table-empty error">{error}</p>}

      <div className="stat-cards">
        <div className="stat-card">
          <span className="stat-label">Total Reports</span>
          <div className="stat-value-row">
            <span className="stat-value">{loading ? "—" : stats.totalReports}</span>
            <span className="stat-icon stat-icon-red">
              <FiClipboard />
            </span>
          </div>
          <span className="stat-desc">All time reports</span>
        </div>

        <div className="stat-card">
          <span className="stat-label">Pending Reports</span>
          <div className="stat-value-row">
            <span className="stat-value">{loading ? "—" : stats.pendingReports}</span>
            <span className="stat-icon stat-icon-yellow">
              <FiClipboard />
            </span>
          </div>
          <span className="stat-desc">Reports awaiting review</span>
        </div>
      </div>

      <div className="recent-reports-card">
        <div className="recent-reports-header">
          <h2>Recent User's Report</h2>
          <button className="view-all-btn" onClick={() => navigate("/reports")}>
            View all
          </button>
        </div>

        {loading ? (
          <p className="table-empty">Loading reports...</p>
        ) : recentReports.length === 0 ? (
          <p className="table-empty">No reports yet.</p>
        ) : (
          <table className="reports-table">
            <thead>
              <tr>
                <th>User</th>
                <th>Product</th>
                <th>Status</th>
                <th>Date</th>
              </tr>
            </thead>
            <tbody>
              {recentReports.map((r) => (
                <tr key={r.id}>
                  <td>
                    <div className="user-cell">
                      <span className="user-name">{r.userName}</span>
                      <span className="user-email">{r.userEmail}</span>
                    </div>
                  </td>
                  <td className="product-cell">{r.productName}</td>
                  <td>
                    <StatusBadge status={r.status} />
                  </td>
                  <td>
                    <div className="date-cell">
                      <span>{formatDate(r.dateSubmitted)}</span>
                      <span className="time">{formatTime(r.dateSubmitted)}</span>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </DashboardLayout>
  );
}
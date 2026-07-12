import { useState, useEffect, useMemo } from "react";
import { useNavigate } from "react-router-dom";
import DashboardLayout from "../components/DashboardLayout";
import StarRating from "../components/StarRating";
import { getAllReviews } from "../services/reviewService";
import { FiEye, FiChevronDown } from "react-icons/fi";
import "./AppReview.css";
import "./Dashboard.css";

function StatusBadge({ status }) {
  const map = {
    New: "badge badge-new",
    "In Progress": "badge badge-progress",
    Resolved: "badge badge-approved",
  };
  return <span className={map[status] || "badge"}>{status}</span>;
}

function isWithinRange(date, range) {
  if (range === "All") return true;
  const now = new Date();
  const diffMs = now - date;
  const day = 24 * 60 * 60 * 1000;

  if (range === "Day") return diffMs <= day;
  if (range === "Week") return diffMs <= 7 * day;
  if (range === "Month") return diffMs <= 30 * day;
  return true;
}

export default function AppReview() {
  const navigate = useNavigate();
  const [reviews, setReviews] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [statusFilter, setStatusFilter] = useState("All Status");
  const [dateFilter, setDateFilter] = useState("All");
  const [statusOpen, setStatusOpen] = useState(false);
  const [dateOpen, setDateOpen] = useState(false);

  useEffect(() => {
    async function load() {
      try {
        const data = await getAllReviews();
        data.sort((a, b) => (b.createdAt?.toDate?.() || 0) - (a.createdAt?.toDate?.() || 0));
        setReviews(data);
      } catch (err) {
        console.error("APP REVIEW LOAD ERROR:", err);
        setError("Failed to load reviews.");
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  const filteredReviews = useMemo(() => {
    return reviews.filter((r) => {
      const matchesStatus =
        statusFilter === "All Status" || r.status === statusFilter;

      const createdDate = r.createdAt?.toDate ? r.createdAt.toDate() : new Date(0);
      const matchesDate = isWithinRange(createdDate, dateFilter);

      return matchesStatus && matchesDate;
    });
  }, [reviews, statusFilter, dateFilter]);

  function formatDate(timestamp) {
    if (!timestamp?.toDate) return "—";
    return timestamp.toDate().toLocaleDateString("en-US", {
      month: "long",
      day: "numeric",
      year: "numeric",
    }).toUpperCase();
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
      <div className="app-review-header">
        <h1 className="page-title">App Review</h1>

        <div className="filters-row">
          <div className="filter-dropdown">
            <button className="filter-btn" onClick={() => setStatusOpen((o) => !o)}>
              {statusFilter} <FiChevronDown />
            </button>
            {statusOpen && (
              <div className="filter-menu">
                {["All Status", "New", "In Progress", "Resolved"].map((s) => (
                  <div
                    key={s}
                    className="filter-item"
                    onClick={() => {
                      setStatusFilter(s);
                      setStatusOpen(false);
                    }}
                  >
                    {s}
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="filter-dropdown">
            <button className="filter-btn" onClick={() => setDateOpen((o) => !o)}>
              {dateFilter} <FiChevronDown />
            </button>
            {dateOpen && (
              <div className="filter-menu">
                {["Day", "Week", "Month", "All"].map((d) => (
                  <div
                    key={d}
                    className="filter-item"
                    onClick={() => {
                      setDateFilter(d);
                      setDateOpen(false);
                    }}
                  >
                    {d}
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="reports-table-card">
        {loading ? (
          <p className="table-empty">Loading reviews...</p>
        ) : error ? (
          <p className="table-empty error">{error}</p>
        ) : filteredReviews.length === 0 ? (
          <p className="table-empty">No reviews found.</p>
        ) : (
          <table className="reports-table">
            <thead>
              <tr>
                <th>User</th>
                <th>Rate</th>
                <th>Review</th>
                <th>Date</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {filteredReviews.map((r) => (
                <tr key={r.id}>
                  <td>
                    <div className="user-cell">
                      <span className="user-name">{r.userName}</span>
                      <span className="user-email">{r.uid}</span>
                    </div>
                  </td>
                  <td>
                    <StarRating rating={r.starNumber || 0} />
                  </td>
                  <td className="review-text-cell">{r.text}</td>
                  <td>
                    <div className="date-cell">
                      <span>{formatDate(r.createdAt)}</span>
                      <span className="time">{formatTime(r.createdAt)}</span>
                    </div>
                  </td>
                  <td>
                    <StatusBadge status={r.status} />
                  </td>
                  <td>
                    <button
                      className="view-icon-btn"
                      onClick={() => navigate(`/app-review/${r.id}`)}
                    >
                      <FiEye />
                    </button>
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
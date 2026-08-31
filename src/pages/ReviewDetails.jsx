import { useState, useEffect, useRef } from "react";
import { useParams, useNavigate } from "react-router-dom";
import DashboardLayout from "../components/DashboardLayout";
import StarRating from "../components/StarRating";
import {
  getReviewById,
  updateReviewStatus,
  replyToReview,
  deleteReview,
} from "../services/reviewService";
import { FiChevronDown, FiSend, FiCheck, FiClock, FiTrash2 } from "react-icons/fi";
import "./ReviewDetails.css";

function StatusBadgeSmall({ status }) {
  const map = {
    New: "status-pill status-new",
    "In Progress": "status-pill status-progress",
    Resolved: "status-pill status-resolved",
  };
  return <span className={map[status] || "status-pill"}>{status}</span>;
}

export default function ReviewDetails() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [review, setReview] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);
  const [replyText, setReplyText] = useState("");
  const [statusMenuOpen, setStatusMenuOpen] = useState(false);
  const [pendingStatus, setPendingStatus] = useState(null);
  const menuRef = useRef(null);

  useEffect(() => {
    async function load() {
      try {
        const data = await getReviewById(id);
        setReview(data);
        setPendingStatus(data.status);
        setReplyText(data.adminReply || "");
      } catch (err) {
        setError("Review not found.");
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [id]);

  useEffect(() => {
    function handleClickOutside(e) {
      if (menuRef.current && !menuRef.current.contains(e.target)) {
        setStatusMenuOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

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

  async function handleDelete() {
    if (!window.confirm("Delete this review permanently? This cannot be undone.")) return;
    setSaving(true);
    try {
      await deleteReview(id);
      navigate("/app-review");
    } catch (err) {
      setError("Failed to delete review.");
      setSaving(false);
    }
  }

  async function handleSave() {
    setSaving(true);
    setError("");
    try {
      if (pendingStatus !== review.status) {
        await updateReviewStatus(id, pendingStatus);
      }
      if (replyText.trim() && replyText !== review.adminReply) {
        await replyToReview(id, replyText.trim());
      }
      setReview((prev) => ({ ...prev, status: pendingStatus, adminReply: replyText.trim() }));
    } catch (err) {
      setError("Failed to save changes. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  if (loading) {
    return (
      <DashboardLayout>
        <p className="page-subtitle">Loading review...</p>
      </DashboardLayout>
    );
  }

  if (error && !review) {
    return (
      <DashboardLayout>
        <p className="table-empty error">{error}</p>
      </DashboardLayout>
    );
  }

  return (
    <DashboardLayout>
      <h1 className="page-title">Review Details</h1>

      <div className="review-details-card">
        <div className="review-summary">
          <div className="review-user">
            <span className="user-name">{review.userName}</span>
            <span className="user-email">{review.userEmail}</span>
          </div>
          <StarRating rating={review.starNumber || 0} showNumber />
          <div className="date-cell">
            <span>{formatDate(review.createdAt)}</span>
            <span className="time">{formatTime(review.createdAt)}</span>
          </div>
        </div>
      </div>

      <div className="review-details-card">
        <p className="review-full-text">{review.text}</p>
      </div>

      <div className="review-actions-card">
        <h3 className="section-title">Review Actions</h3>

        <div className="status-row">
          <span className="status-label">Status</span>
          <div className="status-select-wrapper" ref={menuRef}>
            <button
              className="status-select-btn"
              onClick={() => setStatusMenuOpen((o) => !o)}
            >
              <StatusBadgeSmall status={pendingStatus} />
              <FiChevronDown />
            </button>
            {statusMenuOpen && (
              <div className="status-select-menu">
                <div
                  className="status-select-item"
                  onClick={() => {
                    setPendingStatus("Resolved");
                    setStatusMenuOpen(false);
                  }}
                >
                  <FiCheck className="menu-icon icon-green" /> Mark as Resolved
                </div>
                <div
                  className="status-select-item"
                  onClick={() => {
                    setPendingStatus("In Progress");
                    setStatusMenuOpen(false);
                  }}
                >
                  <FiClock className="menu-icon icon-yellow" /> Mark as In Progress
                </div>
                <div
                  className="status-select-item danger"
                  onClick={handleDelete}
                >
                  <FiTrash2 className="menu-icon icon-red" /> Delete Review
                </div>
              </div>
            )}
          </div>
        </div>

        <textarea
          className="reply-textarea"
          placeholder="Type your reply to the user..."
          value={replyText}
          onChange={(e) => setReplyText(e.target.value)}
          rows={4}
        />

        {error && <p className="form-error">{error}</p>}

        <div className="save-row">
          <button className="save-btn" onClick={handleSave} disabled={saving}>
            <FiSend /> {saving ? "Saving..." : "Save"}
          </button>
        </div>
      </div>
    </DashboardLayout>
  );
}
import { useState, useEffect, useMemo } from "react";
import { useNavigate } from "react-router-dom";
import DashboardLayout from "../components/DashboardLayout";
import { getAllReports } from "../services/reportService";
import { FiSearch, FiChevronDown, FiEye } from "react-icons/fi";
import "./Reports.css";
import "./AppReview.css";
import "./Dashboard.css";

function StatusBadge({ status }) {
  const map = {
    Approve: "badge badge-approved",
    Pending: "badge badge-pending",
    Rejected: "badge badge-rejected",
  };

  return <span className={map[status] || "badge"}>{status}</span>;
}

// Lower number = higher priority (shown first)
const STATUS_ORDER = {
  Pending: 0,
  Approve: 1,
  Rejected: 2,
};

function isWithinRange(date, range) {
  if (range === "All Dates") return true;

  const now = new Date();
  const diffMs = now - date;
  const day = 24 * 60 * 60 * 1000;

  if (range === "Day") return diffMs <= day;
  if (range === "Week") return diffMs <= 7 * day;
  if (range === "Month") return diffMs <= 30 * day;

  return true;
}

export default function Reports() {
  const navigate = useNavigate();

  const [reports, setReports] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("All");
  const [dateFilter, setDateFilter] = useState("All Dates");
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const [dateOpen, setDateOpen] = useState(false);

  useEffect(() => {
    async function load() {
      try {
        const data = await getAllReports();
        setReports(data);
      } catch (err) {
        console.error("REPORT LOAD ERROR:", err);
        setError("Failed to load reports. Please try again.");
      } finally {
        setLoading(false);
      }
    }

    load();
  }, []);

  function getDateValue(r) {
    // Supports Firestore Timestamp or raw Date/number/string
    if (r.dateSubmitted?.toDate) {
      return r.dateSubmitted.toDate().getTime();
    }

    if (r.dateSubmitted) {
      return new Date(r.dateSubmitted).getTime();
    }

    return 0;
  }

  const filteredReports = useMemo(() => {
    const filtered = reports.filter((r) => {
      const searchText = search.toLowerCase();

      const matchesSearch =
        r.userName?.toLowerCase().includes(searchText) ||
        r.productName?.toLowerCase().includes(searchText);

      const matchesStatus =
        statusFilter === "All" || r.status === statusFilter;

      const submittedDate = r.dateSubmitted?.toDate
        ? r.dateSubmitted.toDate()
        : r.dateSubmitted
        ? new Date(r.dateSubmitted)
        : new Date(0);

      const matchesDate = isWithinRange(
        submittedDate,
        dateFilter
      );

      return matchesSearch && matchesStatus && matchesDate;
    });

    return [...filtered].sort((a, b) => {
      const statusDiff =
        (STATUS_ORDER[a.status] ?? 99) -
        (STATUS_ORDER[b.status] ?? 99);

      if (statusDiff !== 0) {
        return statusDiff;
      }

      // Within the same status, most recent first
      return getDateValue(b) - getDateValue(a);
    });
  }, [reports, search, statusFilter, dateFilter]);

  function formatDate(timestamp) {
    if (!timestamp) return "";

    const date = timestamp?.toDate
      ? timestamp.toDate()
      : new Date(timestamp);

    if (isNaN(date.getTime())) return "";

    return date.toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  }

  return (
    <DashboardLayout>
      <h1 className="page-title">Report</h1>

      <div className="reports-toolbar">
        <div className="search-box">
          <input
            type="text"
            placeholder="Search ..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />

          <FiSearch className="search-icon" />
        </div>

        <div className="status-dropdown">
          <button
            className="status-dropdown-btn"
            onClick={() => setDropdownOpen((o) => !o)}
          >
            {statusFilter === "All" ? "All Status" : statusFilter}
            <FiChevronDown />
          </button>

          {dropdownOpen && (
            <div className="status-dropdown-menu">
              {["All", "Pending", "Approve", "Rejected"].map((s) => (
                <div
                  key={s}
                  className="status-dropdown-item"
                  onClick={() => {
                    setStatusFilter(s);
                    setDropdownOpen(false);
                  }}
                >
                  {s}
                </div>
              ))}
            </div>
          )}
        </div>

        {/* DATE FILTER */}
        <div className="filter-dropdown">
          <button
            className="filter-btn"
            onClick={() => setDateOpen((o) => !o)}
          >
            {dateFilter}
            <FiChevronDown />
          </button>

          {dateOpen && (
            <div className="filter-menu">
              {["Day", "Week", "Month", "All Dates"].map((d) => (
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

      <div className="reports-table-card">
        {loading ? (
          <p className="table-empty">Loading reports...</p>
        ) : error ? (
          <p className="table-empty error">{error}</p>
        ) : filteredReports.length === 0 ? (
          <p className="table-empty">No reports found.</p>
        ) : (
          <div className="reports-table-scroll">
            <table className="reports-table">
              <thead>
                <tr>
                  <th>User</th>
                  <th>Product Name</th>
                  <th>Date</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>

              <tbody>
                {filteredReports.map((r) => (
                  <tr key={r.id}>
                    <td>
                      <div className="user-cell">
                        <span className="user-name">
                          {r.userName}
                        </span>

                        <span className="user-email">
                          {r.userEmail}
                        </span>
                      </div>
                    </td>

                    <td className="product-cell">
                      {r.productName}

                      {r.productDescription && (
                        <div className="product-desc">
                          {r.productDescription}
                        </div>
                      )}
                    </td>

                    <td className="date-cell">
                      {formatDate(r.dateSubmitted)}
                    </td>

                    <td>
                      <StatusBadge status={r.status} />
                    </td>

                    <td>
                      <button
                        className="view-icon-btn"
                        onClick={() =>
                          navigate(`/reports/${r.id}`)
                        }
                      >
                        <FiEye />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </DashboardLayout>
  );
}
import { useState, useEffect, useMemo } from "react";
import { useNavigate } from "react-router-dom";
import DashboardLayout from "../components/DashboardLayout";
import { getAllReports } from "../services/reportService";
import { FiSearch, FiChevronDown, FiEye } from "react-icons/fi";
import "./Reports.css";
import "./Dashboard.css";

function StatusBadge({ status }) {
  const map = {
    Approve: "badge badge-approved",
    Pending: "badge badge-pending",
    Rejected: "badge badge-rejected",
  };
  return <span className={map[status] || "badge"}>{status}</span>;
}

export default function Reports() {
  const navigate = useNavigate();
  const [reports, setReports] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("All");
  const [dropdownOpen, setDropdownOpen] = useState(false);

  useEffect(() => {
    async function load() {
      try {
        const data = await getAllReports();
        setReports(data);
      } catch (err) {
        setError("Failed to load reports. Please try again.");
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  const filteredReports = useMemo(() => {
    return reports.filter((r) => {
      const matchesSearch =
        r.userName?.toLowerCase().includes(search.toLowerCase()) ||
        r.productName?.toLowerCase().includes(search.toLowerCase());

      const matchesStatus =
        statusFilter === "All" || r.status === statusFilter;

      return matchesSearch && matchesStatus;
    });
  }, [reports, search, statusFilter]);

  function formatDate(timestamp) {
    if (!timestamp?.toDate) return "";
    return timestamp.toDate().toLocaleDateString("en-US", {
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
            {statusFilter === "All" ? "Status" : statusFilter}
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
      </div>

      <div className="reports-table-card">
        {loading ? (
          <p className="table-empty">Loading reports...</p>
        ) : error ? (
          <p className="table-empty error">{error}</p>
        ) : filteredReports.length === 0 ? (
          <p className="table-empty">No reports found.</p>
        ) : (
          <table className="reports-table">
            <thead>
              <tr>
                <th>User</th>
                <th>Product Name</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredReports.map((r) => (
                <tr key={r.id}>
                  <td>
                    <div className="user-cell">
                      <span className="user-name">{r.userName}</span>
                      <span className="user-email">{r.userEmail}</span>
                    </div>
                  </td>
                  <td className="product-cell">
                    {r.productName}
                    {r.productDescription && (
                      <div className="product-desc">{r.productDescription}</div>
                    )}
                  </td>
                  <td>
                    <StatusBadge status={r.status} />
                  </td>
                  <td>
                    <button
                      className="view-icon-btn"
                      onClick={() => navigate(`/reports/${r.id}`)}
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
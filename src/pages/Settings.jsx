import { useState, useEffect } from "react";
import DashboardLayout from "../components/DashboardLayout";
import { getActivityLogs } from "../services/logService";
import "./Settings.css";
import "./Dashboard.css";

export default function Settings() {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    async function load() {
      try {
        const data = await getActivityLogs(20);
        setLogs(data);
      } catch (err) {
        console.error("ACTIVITY LOG LOAD ERROR:", err);
        setError("Failed to load activity log.");
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  function formatDate(timestamp) {
    if (!timestamp?.toDate) return "—";
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

  return (
    <DashboardLayout>
      <h1 className="page-title">Activity Log</h1>

      <div className="activity-log-card">
        {loading ? (
          <p className="table-empty">Loading activity log...</p>
        ) : error ? (
          <p className="table-empty error">{error}</p>
        ) : logs.length === 0 ? (
          <p className="table-empty">No activity recorded yet.</p>
        ) : (
          <div className="activity-table-scroll">
            <table className="activity-table">
              <thead>
                <tr>
                  <th>Date and Time</th>
                  <th>Activity</th>
                  <th>Admin</th>
                  <th>Details</th>
                </tr>
              </thead>
              <tbody>
                {logs.map((log) => (
                  <tr key={log.id}>
                    <td>
                      <div className="date-cell">
                        <span>{formatDate(log.timestamp)}</span>
                        <span className="time">{formatTime(log.timestamp)}</span>
                      </div>
                    </td>
                    <td className="activity-cell">{log.activity}</td>
                    <td className="activity-cell">{log.adminName || log.adminUid || "—"}</td>
                    <td className="details-cell">
                        {log.label ? (
                            <>
                            <span className="details-label-text">{log.label}</span>
                            <span className="details-id-text">
                                {log.type === "review" ? "Review ID: " : "Report ID: "}
                                {log.targetId || log.reportId}
                            </span>
                            </>
                        ) : (
                            <>{log.type === "review" ? "Review ID: " : "Report ID: "}{log.targetId || log.reportId}</>
                        )}
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
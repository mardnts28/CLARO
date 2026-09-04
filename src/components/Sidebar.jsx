import { NavLink, useNavigate } from "react-router-dom";
import { signOut } from "firebase/auth";
import { auth } from "../firebase/firebase";
import logo from "../assets/images/logoll.png";
import {
  FiHome,
  FiFileText,
  FiSettings,
  FiStar,
  FiLogOut,
  FiChevronRight,
} from "react-icons/fi";
import "./Sidebar.css";

export default function Sidebar({ collapsed }) {
  const navigate = useNavigate();

  async function handleLogout() {
    await signOut(auth);
    navigate("/", { replace: true });
  }

  return (
    <aside className={`sidebar ${collapsed ? "sidebar-collapsed" : ""}`}>
      <div className="sidebar-brand">
          <img src={logo} alt="CLARO Logo" className="sidebar-logo" />
        {!collapsed && <span className="sidebar-brand-text">CLARO</span>}
      </div>

      <nav className="sidebar-nav">
        <NavLink
          to="/dashboard"
          className={({ isActive }) =>
            "sidebar-link" + (isActive ? " active" : "")
          }
        >
          <FiHome className="icon" />
          {!collapsed && <span className="link-text">Dashboard</span>}
        </NavLink>

        <NavLink
          to="/reports"
          className={({ isActive }) =>
            "sidebar-link" + (isActive ? " active" : "")
          }
        >
          <FiFileText className="icon" />
          {!collapsed && (
            <>
              <span className="link-text">Reports</span>
              <FiChevronRight className="chevron" />
            </>
          )}
        </NavLink>

        <NavLink
          to="/app-review"
          className={({ isActive }) =>
            "sidebar-link" + (isActive ? " active" : "")
          }
        >
          <FiStar className="icon" />
          {!collapsed && (
            <>
              <span className="link-text">App Review</span>
              <FiChevronRight className="chevron" />
            </>
          )}
        </NavLink>

        <NavLink
          to="/settings"
          className={({ isActive }) =>
            "sidebar-link" + (isActive ? " active" : "")
          }
        >
          <FiFileText className="icon" />
          {!collapsed && (
            <>
              <span className="link-text">Activity Log</span>
              <FiChevronRight className="chevron" />
            </>
          )}
        </NavLink>
      </nav>

      <button className="sidebar-logout" onClick={handleLogout}>
        <FiLogOut className="icon" />
        {!collapsed && <span className="link-text">Logout</span>}
      </button>
    </aside>
  );
}
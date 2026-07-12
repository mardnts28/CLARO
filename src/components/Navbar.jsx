import { useState, useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { onAuthStateChanged, signOut } from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import { auth, db } from "../firebase/firebase";
import { FiMenu, FiUser, FiChevronDown, FiLogOut, FiUserCheck } from "react-icons/fi";
import "./Navbar.css";

export default function Navbar({ onToggleSidebar }) {
  const navigate = useNavigate();
  const [adminName, setAdminName] = useState("Admin User");
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const menuRef = useRef(null);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (user) => {
      if (!user) return;
      const adminRef = doc(db, "admins", user.uid);
      const adminSnap = await getDoc(adminRef);
      if (adminSnap.exists()) {
        setAdminName(adminSnap.data().name || "Admin User");
      }
    });
    return unsub;
  }, []);

  useEffect(() => {
    function handleClickOutside(e) {
      if (menuRef.current && !menuRef.current.contains(e.target)) {
        setDropdownOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  async function handleLogout() {
    await signOut(auth);
    navigate("/", { replace: true });
  }

  return (
    <header className="navbar">
      <button className="menu-btn" onClick={onToggleSidebar} aria-label="Toggle sidebar">
        <FiMenu />
      </button>

      <div className="navbar-profile-wrapper" ref={menuRef}>
        <div className="navbar-right" onClick={() => setDropdownOpen((o) => !o)}>
          <span className="navbar-admin-name">{adminName}</span>
          <span className="navbar-avatar">
            <FiUser />
          </span>
          <FiChevronDown className="navbar-caret" />
        </div>

        {dropdownOpen && (
          <div className="navbar-dropdown">
            <div
              className="navbar-dropdown-item"
              onClick={() => {
                setDropdownOpen(false);
                navigate("/profile");
              }}
            >
              <FiUserCheck /> View Profile
            </div>
            <div className="navbar-dropdown-item danger" onClick={handleLogout}>
              <FiLogOut /> Logout
            </div>
          </div>
        )}
      </div>
    </header>
  );
}
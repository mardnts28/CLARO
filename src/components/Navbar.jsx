import { useState, useEffect } from "react";
import { onAuthStateChanged } from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import { auth, db } from "../firebase/firebase";
import { FiMenu, FiUser, FiChevronDown } from "react-icons/fi";
import "./Navbar.css";

export default function Navbar({ onToggleSidebar }) {
  const [adminName, setAdminName] = useState("Admin User");

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

  return (
    <header className="navbar">
      <button className="menu-btn" onClick={onToggleSidebar} aria-label="Toggle sidebar">
        <FiMenu />
      </button>

      <div className="navbar-right">
        <span className="navbar-admin-name">{adminName}</span>
        <span className="navbar-avatar">
          <FiUser />
        </span>
        <FiChevronDown className="navbar-caret" />
      </div>
    </header>
  );
}
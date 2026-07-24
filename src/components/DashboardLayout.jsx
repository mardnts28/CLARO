import { useState } from "react";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";
import "./DashboardLayout.css";

export default function DashboardLayout({ children }) {
  const [collapsed, setCollapsed] = useState(false);

  return (
    <div className="layout">
      <Sidebar collapsed={collapsed} />
      <div className="layout-main">
        <Navbar onToggleSidebar={() => setCollapsed((c) => !c)} />
        <div className="layout-content">{children}</div>
      </div>
    </div>
  );
}
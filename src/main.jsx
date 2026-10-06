import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import "./index.css";

// Poppins weights used across the admin UI
import "@fontsource/poppins/400.css";
import "@fontsource/poppins/500.css";
import "@fontsource/poppins/600.css";
import "@fontsource/poppins/700.css";
import "@fontsource/poppins/800.css";

// CSP Violation Monitoring (for report-only mode)
import { setupCSPMonitoring } from "./utils/CSPViolationHandler";

// Setup CSP monitoring on app initialization
setupCSPMonitoring();

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
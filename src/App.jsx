import { BrowserRouter, Routes, Route } from "react-router-dom";
import Login from "./pages/Login";
import OTPVerification from "./pages/OTPVerification";
import ChangePasswordFirstTime from "./pages/ChangePasswordFirstTime";
import Dashboard from "./pages/Dashboard";
import Profile from "./pages/Profile";
import Reports from "./pages/Reports";
import ReportDetails from "./pages/ReportDetails";
import ReviewDetails from "./pages/ReviewDetails"
import Settings from "./pages/Settings";
import AppReview from "./pages/AppReview";
import ProtectedRoute from "./components/ProtectedRoute";

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Login />} />
        <Route path="/verify-otp" element={<OTPVerification />} />
        <Route path="/change-password" element={<ChangePasswordFirstTime />} />

        <Route path="/dashboard" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
        <Route path="/reports" element={<ProtectedRoute><Reports /></ProtectedRoute>} />
        <Route path="/reports/:id" element={<ProtectedRoute><ReportDetails /></ProtectedRoute>} />
        <Route path="/settings" element={<ProtectedRoute><Settings /></ProtectedRoute>} />
        <Route path="/app-review" element={<ProtectedRoute><AppReview /></ProtectedRoute>} />
        <Route path="/profile" element={<ProtectedRoute><Profile /></ProtectedRoute>} />
        <Route path="/app-review/:id" element={<ProtectedRoute><ReviewDetails /></ProtectedRoute>} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
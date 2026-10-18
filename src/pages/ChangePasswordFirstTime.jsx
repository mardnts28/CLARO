import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { onAuthStateChanged } from "firebase/auth";
import { auth } from "../firebase/firebase";
import logo from "../assets/images/logoll.png";
import { changePasswordFirstTime } from "../services/profileService";
import { FiAlertCircle, FiCheckCircle } from "react-icons/fi";
import "./Login.css";
import "./ChangePasswordFirstTime.css";

// Password requirements (same as mobile app signup)
const passwordRequirements = [
  { label: "At least 8 characters", test: (v) => v.length >= 8 },
  { label: "One uppercase letter", test: (v) => /[A-Z]/.test(v) },
  { label: "One lowercase letter", test: (v) => /[a-z]/.test(v) },
  { label: "One number", test: (v) => /[0-9]/.test(v) },
  { label: "One special character (!@#$%^&* etc.)", test: (v) => /[!@#$%^&*(),.?":{}|<>]/.test(v) },
];

export default function ChangePasswordFirstTime() {
  const navigate = useNavigate();
  const [checkingAuth, setCheckingAuth] = useState(true);
  const [newPassword, setNewPassword] = useState("");
  const [retypePassword, setRetypePassword] = useState("");
  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showRetypePassword, setShowRetypePassword] = useState(false);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, (user) => {
      if (!user) {
        navigate("/", { replace: true });
      }
      setCheckingAuth(false);
    });
    return unsub;
  }, [navigate]);

  function validatePassword(password) {
    const newErrors = {};
    if (!password) {
      newErrors.newPassword = "New password is required.";
    } else {
      const failed = passwordRequirements.filter((req) => !req.test(password));
      if (failed.length > 0) {
        newErrors.newPassword = "Password does not meet all requirements.";
      }
    }
    return newErrors;
  }

  async function handleSubmit(e) {
    e.preventDefault();
    const newErrors = {};

    if (!newPassword) newErrors.newPassword = "New password is required.";
    else {
      const passwordErrors = validatePassword(newPassword);
      if (passwordErrors.newPassword) newErrors.newPassword = passwordErrors.newPassword;
    }

    if (!retypePassword) newErrors.retypePassword = "Please retype your new password.";
    else if (newPassword && retypePassword !== newPassword) newErrors.retypePassword = "Passwords do not match.";

    setErrors(newErrors);
    if (Object.keys(newErrors).length > 0) return;

    setLoading(true);
    try {
      await changePasswordFirstTime(newPassword);
      navigate("/dashboard", { replace: true });
    } catch (err) {
      const message =
        err.code === "auth/requires-recent-login"
          ? "Your session has expired. Please log in again and set your new password."
          : err.code === "auth/weak-password"
          ? "Password is too weak. Use at least 8 characters, including uppercase, lowercase, number, and special character."
          : "Failed to set new password. Please try again.";
      setErrors({ form: message });
    } finally {
      setLoading(false);
    }
  }

  if (checkingAuth) return null;

  return (
    <div className="login-page">
      <div className="login-header">
        <img src={logo} alt="CLARO Logo" className="login-logo" />
        <h1 className="brand-name">CLARO</h1>
      </div>

      <div className="login-card">
        <h2>Set a New Password</h2>
        <p className="subtitle">
          For your account's security, please create a new password before continuing.
        </p>

        <form onSubmit={handleSubmit} noValidate>
          <div className="input-group">
            <div className="password-input-wrapper">
              <input
                type={showPassword ? "text" : "password"}
                placeholder="New Password"
                value={newPassword}
                onChange={(e) => {
                  setNewPassword(e.target.value);
                  if (errors.newPassword) setErrors((prev) => ({ ...prev, newPassword: "" }));
                }}
                className={errors.newPassword ? "input-error" : ""}
              />
              <button
                type="button"
                className="toggle-password"
                onClick={() => setShowPassword(!showPassword)}
              >
                {showPassword ? "Hide" : "Show"}
              </button>
            </div>
            {errors.newPassword && <span className="field-error">{errors.newPassword}</span>}
          </div>

          {/* Password requirements panel (always visible) */}
          <div className="password-requirements">
            {passwordRequirements.map((req, index) => {
              const isMet = req.test(newPassword);
              return (
                <div key={index} className={`requirement-item ${isMet ? "met" : ""}`}>
                  {isMet ? (
                    <FiCheckCircle className="requirement-icon" />
                  ) : (
                    <div className="requirement-dot" />
                  )}
                  <span>{req.label}</span>
                </div>
              );
            })}
          </div>

          <div className="input-group">
            <div className="password-input-wrapper">
              <input
                type={showRetypePassword ? "text" : "password"}
                placeholder="Retype New Password"
                value={retypePassword}
                onChange={(e) => {
                  setRetypePassword(e.target.value);
                  if (errors.retypePassword) setErrors((prev) => ({ ...prev, retypePassword: "" }));
                }}
                className={errors.retypePassword ? "input-error" : ""}
              />
              <button
                type="button"
                className="toggle-password"
                onClick={() => setShowRetypePassword(!showRetypePassword)}
              >
                {showRetypePassword ? "Hide" : "Show"}
              </button>
            </div>
            {errors.retypePassword && <span className="field-error">{errors.retypePassword}</span>}
          </div>

          {errors.form && (
            <div className="form-error" role="alert">
              <FiAlertCircle className="form-error-icon" />
              <span>{errors.form}</span>
            </div>
          )}

          <button type="submit" className="login-btn" disabled={loading}>
            {loading ? "Saving..." : "Save New Password"}
          </button>
        </form>
      </div>
    </div>
  );
}
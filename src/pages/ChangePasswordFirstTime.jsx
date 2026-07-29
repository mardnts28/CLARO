import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { onAuthStateChanged } from "firebase/auth";
import { auth } from "../firebase/firebase";
import logo from "../assets/images/logoll.png";
import { changePasswordFirstTime } from "../services/profileService";
import "./Login.css";

export default function ChangePasswordFirstTime() {
  const navigate = useNavigate();
  const [checkingAuth, setCheckingAuth] = useState(true);
  const [newPassword, setNewPassword] = useState("");
  const [retypePassword, setRetypePassword] = useState("");
  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, (user) => {
      if (!user) {
        navigate("/", { replace: true });
      }
      setCheckingAuth(false);
    });
    return unsub;
  }, [navigate]);

  async function handleSubmit(e) {
    e.preventDefault();
    const newErrors = {};

    if (!newPassword) newErrors.newPassword = "New password is required.";
    else if (newPassword.length < 6) newErrors.newPassword = "Password must be at least 6 characters.";
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
          ? "Password is too weak (minimum 6 characters)."
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
            <input
              type="password"
              placeholder="New Password"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              className={errors.newPassword ? "input-error" : ""}
            />
            {errors.newPassword && <span className="field-error">{errors.newPassword}</span>}
          </div>

          <div className="input-group">
            <input
              type="password"
              placeholder="Retype New Password"
              value={retypePassword}
              onChange={(e) => setRetypePassword(e.target.value)}
              className={errors.retypePassword ? "input-error" : ""}
            />
            {errors.retypePassword && <span className="field-error">{errors.retypePassword}</span>}
          </div>

          {errors.form && <div className="form-error">{errors.form}</div>}

          <button type="submit" className="login-btn" disabled={loading}>
            {loading ? "Saving..." : "Save New Password"}
          </button>
        </form>
      </div>
    </div>
  );
}
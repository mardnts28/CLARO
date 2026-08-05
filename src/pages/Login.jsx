import { useState } from "react";
import { useNavigate } from "react-router-dom";
import logo from "../assets/images/logoll.png";
import { loginAdmin, resetPassword, firebaseErrorMessages } from "../services/authService";
import "./Login.css";

export default function Login() {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);

  const [showResetForm, setShowResetForm] = useState(false);
  const [resetEmail, setResetEmail] = useState("");
  const [resetLoading, setResetLoading] = useState(false);
  const [resetMessage, setResetMessage] = useState("");
  const [resetError, setResetError] = useState("");

  function validate() {
    const newErrors = {};
    const trimmedEmail = email.trim();

    if (!trimmedEmail) {
      newErrors.email = "Email is required.";
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmedEmail)) {
      newErrors.email = "Invalid email format.";
    }

    if (!password) {
      newErrors.password = "Password is required.";
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!validate()) return;

    setLoading(true);
    setErrors({});

    try {
      const admin = await loginAdmin(email.trim(), password);

      // MFA/OTP step temporarily disabled (EmailJS free tier limits).
      // Re-enable later by restoring generateAndSendOTP + navigate("/verify-otp").
      // Mandatory password change for first-time logins is still enforced
      // via the existing `mustChangePassword` field on the admin doc.
      if (admin.mustChangePassword) {
        navigate("/change-password", { replace: true, state: { firstTime: true } });
      } else {
        navigate("/dashboard", { replace: true });
      }
    } catch (err) {
      if (err.code === "not-admin") {
        setErrors({ form: "You are not authorized to access this dashboard." });
      } else {
        const message = firebaseErrorMessages[err.code] || "Something went wrong. Please try again.";
        setErrors({ form: message });
      }
    } finally {
      setLoading(false);
    }
  }

  function openResetForm() {
    setResetEmail(email.trim());
    setResetMessage("");
    setResetError("");
    setShowResetForm(true);
  }

  async function handleResetPassword(e) {
    e.preventDefault();
    setResetMessage("");
    setResetError("");

    const trimmed = resetEmail.trim();
    if (!trimmed || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed)) {
      setResetError("Please enter a valid email address.");
      return;
    }

    setResetLoading(true);
    try {
      await resetPassword(trimmed);
      setResetMessage("Password reset link sent. Please check your inbox.");
    } catch (err) {
      setResetError(firebaseErrorMessages[err.code] || "Failed to send reset email. Please try again.");
    } finally {
      setResetLoading(false);
    }
  }

  if (showResetForm) {
    return (
      <div className="login-page">
        <div className="login-header">
          <img src={logo} alt="CLARO Logo" className="login-logo" />
          <h1 className="brand-name">CLARO</h1>
        </div>

        <div className="login-card">
          <h2>Reset Password</h2>
          <p className="subtitle">
            Enter your admin email and we'll send you a link to reset your password.
          </p>

          <form onSubmit={handleResetPassword} noValidate>
            <div className="input-group">
              <input
                type="email"
                placeholder="Email"
                value={resetEmail}
                onChange={(e) => setResetEmail(e.target.value)}
                className={resetError ? "input-error" : ""}
              />
            </div>

            {resetError && <div className="form-error">{resetError}</div>}
            {resetMessage && <p className="success-msg">{resetMessage}</p>}

            <button type="submit" className="login-btn" disabled={resetLoading}>
              {resetLoading ? "Sending..." : "Send Reset Link"}
            </button>
          </form>

          <button
            className="resend-btn"
            type="button"
            onClick={() => setShowResetForm(false)}
          >
            Back to Login
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="login-page">
      <div className="login-header">
        <img src={logo} alt="CLARO Logo" className="login-logo" />
        <h1 className="brand-name">CLARO</h1>
      </div>

      <div className="login-card">
        <h2>Admin Login</h2>
        <p className="subtitle">Please sign in to your admin account</p>

        <form onSubmit={handleSubmit} noValidate>
          <div className="input-group">
            <input
              type="email"
              placeholder="Email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className={errors.email ? "input-error" : ""}
            />
            {errors.email && <span className="field-error">{errors.email}</span>}
          </div>

          <div className="input-group">
            <input
              type={showPassword ? "text" : "password"}
              placeholder="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className={errors.password ? "input-error" : ""}
            />
            <button
              type="button"
              className="toggle-password"
              onClick={() => setShowPassword((s) => !s)}
            >
              {showPassword ? "Hide" : "Show"}
            </button>
            {errors.password && <span className="field-error">{errors.password}</span>}
          </div>

          <div className="forgot-password-row">
            <button type="button" className="forgot-password-link" onClick={openResetForm}>
              Forgot password?
            </button>
          </div>

          {errors.form && <div className="form-error">{errors.form}</div>}

          <button type="submit" className="login-btn" disabled={loading}>
            {loading ? "Logging in..." : "Login"}
          </button>
        </form>
      </div>
    </div>
  );
}
import { useState, useEffect } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import logo from "../assets/images/logoll.png";
import {
  loginAdmin,
  resetPassword,
  checkAccountLockout,
  firebaseErrorMessages,
  MAX_FAILED_ATTEMPTS,
} from "../services/authService";
import { generateAndSendOTP } from "../services/otpService";
import { signOut } from "firebase/auth";
import { auth } from "../firebase/firebase";
import TurnstileWidget from "../components/TurnstileWidget";
import { FiAlertCircle, FiClock, FiShield } from "react-icons/fi";
import "./Login.css";

export default function Login() {
  const navigate = useNavigate();
  const location = useLocation();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);

  // Inactivity timeout notice from SessionTimeoutManager
  const [timeoutNotice, setTimeoutNotice] = useState(
    location.state?.timeoutNotice || ""
  );

  // Rate limiting / Account lockout state
  const [lockoutState, setLockoutState] = useState({
    isLocked: false,
    remainingSeconds: 0,
    lockedUntil: null,
  });

  // Bot Protection (Cloudflare Turnstile token)
  const [turnstileToken, setTurnstileToken] = useState(null);

  // Reset password form state
  const [showResetForm, setShowResetForm] = useState(false);
  const [resetEmail, setResetEmail] = useState("");
  const [resetLoading, setResetLoading] = useState(false);
  const [resetMessage, setResetMessage] = useState("");
  const [resetError, setResetError] = useState("");

  // Lockout countdown timer
  useEffect(() => {
    if (!lockoutState.isLocked || !lockoutState.lockedUntil) return;

    const timer = setInterval(() => {
      const remainingMs = lockoutState.lockedUntil - Date.now();
      if (remainingMs <= 0) {
        setLockoutState({ isLocked: false, remainingSeconds: 0, lockedUntil: null });
        clearInterval(timer);
      } else {
        setLockoutState((prev) => ({
          ...prev,
          remainingSeconds: Math.ceil(remainingMs / 1000),
        }));
      }
    }, 1000);

    return () => clearInterval(timer);
  }, [lockoutState.isLocked, lockoutState.lockedUntil]);

  // Check lockout on email blur/change
  async function handleEmailBlur() {
    if (!email.trim() || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) return;
    const status = await checkAccountLockout(email.trim());
    if (status.isLocked) {
      setLockoutState({
        isLocked: true,
        remainingSeconds: status.remainingSeconds,
        lockedUntil: status.lockedUntil,
      });
    }
  }

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
    if (lockoutState.isLocked) return;
    if (!validate()) return;

    setLoading(true);
    setErrors({});
    setTimeoutNotice("");

    try {
      const admin = await loginAdmin(email.trim(), password);

      sessionStorage.removeItem(`claro:otp-verified:${admin.uid}`);
      let expiresAt;
      try {
        ({ expiresAt } = await generateAndSendOTP(admin.uid, email.trim()));
      } catch (err) {
        await signOut(auth);
        throw err;
      }

      navigate("/verify-otp", {
        replace: true,
        state: {
          uid: admin.uid,
          email: email.trim(),
          otpExpiresAt: expiresAt.getTime(),
          mustChangePassword: admin.mustChangePassword === true,
        },
      });
    } catch (err) {
      console.error("LOGIN ERROR:", err);

      if (err.code === "auth/account-locked") {
        const remainingMs = (err.lockedUntil || Date.now() + 15 * 60 * 1000) - Date.now();
        setLockoutState({
          isLocked: true,
          remainingSeconds: Math.max(1, Math.ceil(remainingMs / 1000)),
          lockedUntil: err.lockedUntil || Date.now() + 15 * 60 * 1000,
        });
      } else if (err.code === "not-admin") {
        setErrors({ form: "You are not authorized to access this dashboard." });
      } else if (err.attempts !== undefined) {
        const remaining = err.remainingAttempts;
        setErrors({
          form: `Incorrect email or password. Attempt ${err.attempts} of ${MAX_FAILED_ATTEMPTS}. (${remaining} attempt${remaining === 1 ? "" : "s"} before 15-minute lockout)`,
        });
      } else {
        const message =
          firebaseErrorMessages[err.code] || "Something went wrong. Please try again.";
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
      setResetError(
        firebaseErrorMessages[err.code] || "Failed to send reset email. Please try again."
      );
    } finally {
      setResetLoading(false);
    }
  }

  function formatRemainingTime(seconds) {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}m ${secs.toString().padStart(2, "0")}s`;
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

            {resetError && (
              <div className="form-error" role="alert">
                <FiAlertCircle className="form-error-icon" />
                <span>{resetError}</span>
              </div>
            )}
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

        {/* Inactivity Auto-Logout Notification Banner */}
        {timeoutNotice && (
          <div className="login-notice" role="alert">
            <FiClock />
            <span>{timeoutNotice}</span>
          </div>
        )}

        {/* Rate Limiting / Lockout Alert Banner */}
        {lockoutState.isLocked && (
          <div className="lockout-banner" role="alert">
            <div className="lockout-banner-header">
              <FiShield />
              <span>Account Temporarily Locked</span>
            </div>
            <p>
              Too many consecutive failed login attempts. Try again in:{" "}
              <span className="lockout-timer">
                {formatRemainingTime(lockoutState.remainingSeconds)}
              </span>
            </p>
          </div>
        )}

        <form onSubmit={handleSubmit} noValidate>
          <div className="input-group">
            <input
              type="email"
              placeholder="Email"
              value={email}
              onBlur={handleEmailBlur}
              onChange={(e) => {
                setEmail(e.target.value);
                if (errors.email) setErrors((prev) => ({ ...prev, email: "" }));
                if (errors.form) setErrors((prev) => ({ ...prev, form: "" }));
              }}
              className={errors.email ? "input-error" : ""}
            />
            {errors.email && <span className="field-error">{errors.email}</span>}
          </div>

          <div className="input-group">
            <input
              type={showPassword ? "text" : "password"}
              placeholder="Password"
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                if (errors.password) setErrors((prev) => ({ ...prev, password: "" }));
                if (errors.form) setErrors((prev) => ({ ...prev, form: "" }));
              }}
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

          {errors.form && (
            <div className="form-error" role="alert">
              <FiAlertCircle className="form-error-icon" />
              <span>{errors.form}</span>
            </div>
          )}

          {/* Cloudflare Bot Protection Widget */}
          <TurnstileWidget onVerify={(token) => setTurnstileToken(token)} />

          <button
            type="submit"
            className="login-btn"
            disabled={loading || lockoutState.isLocked}
          >
            {loading
              ? "Logging in..."
              : lockoutState.isLocked
              ? "Account Locked"
              : "Login"}
          </button>
        </form>
      </div>
    </div>
  );
}
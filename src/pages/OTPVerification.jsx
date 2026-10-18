import { useState, useEffect, useRef } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { doc, getDoc } from "firebase/firestore";
import { db } from "../firebase/firebase";
import { verifyOTP, generateAndSendOTP, otpErrorMessages, OTP_EXPIRY_MINUTES } from "../services/otpService";
import { FiAlertCircle } from "react-icons/fi";
import "./Login.css";
import "./OTPVerification.css";

// Password requirements (for consistency across screens)
const passwordRequirements = [
  { label: "At least 8 characters", test: (v) => v.length >= 8 },
  { label: "One uppercase letter", test: (v) => /[A-Z]/.test(v) },
  { label: "One lowercase letter", test: (v) => /[a-z]/.test(v) },
  { label: "One number", test: (v) => /[0-9]/.test(v) },
  { label: "One special character (!@#$%^&* etc.)", test: (v) => /[!@#$%^&*(),.?":{}|<>]/.test(v) },
];

export default function OTPVerification() {
  const { state } = useLocation();
  const navigate = useNavigate();
  const [digits, setDigits] = useState(new Array(6).fill(""));
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [resending, setResending] = useState(false);
  const [cooldown, setCooldown] = useState(15); // Start with 15 second cooldown (same as mobile app)
  const [expiresAt, setExpiresAt] = useState(state?.otpExpiresAt || null);
  const [secondsLeft, setSecondsLeft] = useState(
    state?.otpExpiresAt ? Math.max(0, Math.round((state.otpExpiresAt - Date.now()) / 1000)) : 0
  );
  const inputsRef = useRef([]);

  useEffect(() => {
    if (!state?.uid) {
      navigate("/", { replace: true });
    }
  }, [state, navigate]);

  // Start cooldown timer immediately on mount
  useEffect(() => {
    if (cooldown <= 0) return;
    const timer = setInterval(() => setCooldown((c) => c - 1), 1000);
    return () => clearInterval(timer);
  }, [cooldown]);

  // Live countdown showing time left until the OTP expires
  useEffect(() => {
    if (!expiresAt) return;
    const timer = setInterval(() => {
      const remaining = Math.max(0, Math.round((expiresAt - Date.now()) / 1000));
      setSecondsLeft(remaining);
      if (remaining <= 0) clearInterval(timer);
    }, 1000);
    return () => clearInterval(timer);
  }, [expiresAt]);

  const isExpired = expiresAt !== null && secondsLeft <= 0;

  function formatCountdown(totalSeconds) {
    const m = Math.floor(totalSeconds / 60);
    const s = totalSeconds % 60;
    return `${m}:${s.toString().padStart(2, "0")}`;
  }

  function handleChange(index, value) {
    if (!/^\d?$/.test(value)) return;
    const newDigits = [...digits];
    newDigits[index] = value;
    setDigits(newDigits);

    if (value && index < 5) {
      inputsRef.current[index + 1]?.focus();
    }
  }

  function handleKeyDown(index, e) {
    if (e.key === "Backspace" && !digits[index] && index > 0) {
      inputsRef.current[index - 1]?.focus();
    }
  }

  async function handleVerify(e) {
    e.preventDefault();

    if (isExpired) {
      setError("Your OTP has expired. Please resend to get a new one.");
      return;
    }

    const code = digits.join("");

    if (code.length !== 6) {
      setError("OTP must be 6 digits.");
      return;
    }

    setLoading(true);
    setError("");

    try {
      await verifyOTP(state.uid, code);
      sessionStorage.setItem(`claro:otp-verified:${state.uid}`, "true");

      const adminSnap = await getDoc(doc(db, "admins", state.uid));
      const mustChangePassword = state.mustChangePassword === true ||
        (adminSnap.exists() && adminSnap.data().mustChangePassword === true);

      if (mustChangePassword) {
        navigate("/change-password", { replace: true, state: { firstTime: true } });
      } else {
        navigate("/dashboard", { replace: true });
      }
    } catch (err) {
      setError(otpErrorMessages[err.code] || "Verification failed. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  async function handleResend() {
    if (cooldown > 0 || resending) return;
    setResending(true);
    try {
      const { expiresAt: newExpiresAt } = await generateAndSendOTP(state.uid, state.email);
      setCooldown(15); // Reset cooldown to 15 seconds (same as mobile app)
      setError("");
      setDigits(new Array(6).fill(""));
      setExpiresAt(newExpiresAt.getTime());
      setSecondsLeft(OTP_EXPIRY_MINUTES * 60);
    } catch {
      setError("Failed to resend OTP. Please try again.");
    } finally {
      setResending(false);
    }
  }

  return (
    <div className="login-page">
      <div className="login-card">
        <h2>OTP Verification</h2>
        <p className="subtitle">
          Enter the 6-digit code sent to <strong>{state?.email}</strong>
        </p>

        {expiresAt && (
          <p className={isExpired ? "otp-timer otp-timer-expired" : "otp-timer"}>
            {isExpired
              ? "OTP expired"
              : `Code expires in ${formatCountdown(secondsLeft)}`}
          </p>
        )}

        <form onSubmit={handleVerify}>
          <div className="otp-inputs">
            {digits.map((d, i) => (
              <input
                key={i}
                ref={(el) => (inputsRef.current[i] = el)}
                type="text"
                inputMode="numeric"
                maxLength={1}
                value={d}
                onChange={(e) => handleChange(i, e.target.value)}
                onKeyDown={(e) => handleKeyDown(i, e)}
                className="otp-box"
                disabled={isExpired}
              />
            ))}
          </div>

          {error && (
            <div className="form-error" role="alert">
              <FiAlertCircle className="form-error-icon" />
              <span>{error}</span>
            </div>
          )}

          <button type="submit" className="login-btn" disabled={loading || isExpired}>
            {loading ? "Verifying..." : "Verify"}
          </button>
        </form>

        <button
          className="resend-btn"
          onClick={handleResend}
          disabled={cooldown > 0 || resending}
        >
          {resending ? "Sending..." : cooldown > 0 ? `Resend Code in ${formatCountdown(cooldown)}` : "Resend Code"}
        </button>
      </div>
    </div>
  );
}
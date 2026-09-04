import { useState, useEffect, useRef } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { doc, getDoc } from "firebase/firestore";
import { db } from "../firebase/firebase";
import { verifyOTP, generateAndSendOTP, otpErrorMessages, OTP_EXPIRY_MINUTES } from "../services/otpService";
import "./Login.css";
import "./OTPVerification.css";

export default function OTPVerification() {
  const { state } = useLocation();
  const navigate = useNavigate();
  const [digits, setDigits] = useState(new Array(6).fill(""));
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [cooldown, setCooldown] = useState(0);
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
    if (cooldown > 0) return;
    try {
      const { expiresAt: newExpiresAt } = await generateAndSendOTP(state.uid, state.email);
      setCooldown(60);
      setError("");
      setDigits(new Array(6).fill(""));
      setExpiresAt(newExpiresAt.getTime());
      setSecondsLeft(OTP_EXPIRY_MINUTES * 60);
    } catch {
      setError("Failed to resend OTP. Please try again.");
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

          {error && <div className="form-error">{error}</div>}

          <button type="submit" className="login-btn" disabled={loading || isExpired}>
            {loading ? "Verifying..." : "Verify"}
          </button>
        </form>

        <button
          className="resend-btn"
          onClick={handleResend}
          disabled={cooldown > 0}
        >
          {cooldown > 0 ? `Resend OTP (${cooldown}s)` : "Resend OTP"}
        </button>
      </div>
    </div>
  );
}
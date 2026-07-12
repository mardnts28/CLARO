import { useState } from "react";
import { useNavigate } from "react-router-dom";
import logo from "../assets/images/logoll.png";
import { loginAdmin, firebaseErrorMessages } from "../services/authService";
import { generateAndSendOTP } from "../services/otpService";
import "./Login.css";

export default function Login() {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);

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
      await generateAndSendOTP(admin.uid, admin.email);

      navigate("/verify-otp", { state: { uid: admin.uid, email: admin.email } });
    } catch (err) {
        console.error("FULL ERROR OBJECT:", err);
        console.error("ERROR CODE:", err.code);
        console.error("ERROR MESSAGE:", err.message);
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

          {errors.form && <div className="form-error">{errors.form}</div>}

          <button type="submit" className="login-btn" disabled={loading}>
            {loading ? "Logging in..." : "Login"}
          </button>
        </form>
      </div>
    </div>
  );
}
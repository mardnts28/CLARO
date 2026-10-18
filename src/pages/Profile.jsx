import { useState, useEffect } from "react";
import { onAuthStateChanged } from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import { auth, db } from "../firebase/firebase";
import DashboardLayout from "../components/DashboardLayout";
import {
  updateUsername,
  changePassword,
  profileErrorMessages,
} from "../services/profileService";
import { FiUser, FiCheckCircle } from "react-icons/fi";
import "./Profile.css";

// Password requirements (same as mobile app signup)
const passwordRequirements = [
  { label: "At least 8 characters", test: (v) => v.length >= 8 },
  { label: "One uppercase letter", test: (v) => /[A-Z]/.test(v) },
  { label: "One lowercase letter", test: (v) => /[a-z]/.test(v) },
  { label: "One number", test: (v) => /[0-9]/.test(v) },
  { label: "One special character (!@#$%^&* etc.)", test: (v) => /[!@#$%^&*(),.?":{}|<>]/.test(v) },
];

export default function Profile() {
  const [uid, setUid] = useState(null);
  const [email, setEmail] = useState("");
  const [username, setUsername] = useState("");
  const [originalUsername, setOriginalUsername] = useState("");

  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [retypePassword, setRetypePassword] = useState("");

  const [errors, setErrors] = useState({});
  const [usernameSaving, setUsernameSaving] = useState(false);
  const [passwordSaving, setPasswordSaving] = useState(false);
  const [usernameSuccess, setUsernameSuccess] = useState("");
  const [passwordSuccess, setPasswordSuccess] = useState("");
  const [showCurrentPassword, setShowCurrentPassword] = useState(false);
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [showRetypePassword, setShowRetypePassword] = useState(false);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (user) => {
      if (!user) return;

      setUid(user.uid);
      setEmail(user.email || "");

      const adminRef = doc(db, "admins", user.uid);
      const adminSnap = await getDoc(adminRef);

      if (adminSnap.exists()) {
        const name = adminSnap.data().name || "";
        setUsername(name);
        setOriginalUsername(name);
      }
    });

    return unsub;
  }, []);

  async function handleUsernameSave(e) {
    e.preventDefault();

    setErrors((prev) => ({
      ...prev,
      username: "",
    }));

    setUsernameSuccess("");

    const trimmed = username.trim();

    if (!trimmed) {
      setErrors((prev) => ({
        ...prev,
        username: "Username is required.",
      }));
      return;
    }

    if (trimmed === originalUsername) {
      setErrors((prev) => ({
        ...prev,
        username: "No changes to save.",
      }));
      return;
    }

    setUsernameSaving(true);

    try {
      await updateUsername(uid, trimmed);

      setOriginalUsername(trimmed);
      setUsernameSuccess("Username updated successfully.");
    } catch (err) {
      console.error("USERNAME UPDATE ERROR:", err);

      setErrors((prev) => ({
        ...prev,
        username: "Failed to update username. Please try again.",
      }));
    } finally {
      setUsernameSaving(false);
    }
  }

  async function handlePasswordSave(e) {
    e.preventDefault();

    const newErrors = {};

    if (!currentPassword) {
      newErrors.currentPassword = "Current password is required.";
    }

    if (!newPassword) {
      newErrors.newPassword = "New password is required.";
    } else {
      const failed = passwordRequirements.filter((req) => !req.test(newPassword));
      if (failed.length > 0) {
        newErrors.newPassword = "Password does not meet all requirements.";
      }
    }

    if (!retypePassword) {
      newErrors.retypePassword =
        "Please retype your new password.";
    } else if (
      newPassword &&
      retypePassword !== newPassword
    ) {
      newErrors.retypePassword = "Passwords do not match.";
    }

    if (
      currentPassword &&
      newPassword &&
      currentPassword === newPassword
    ) {
      newErrors.newPassword =
        "New password must be different from current password.";
    }

    setErrors((prev) => ({
      ...prev,
      ...newErrors,
      form: "",
    }));

    setPasswordSuccess("");

    if (Object.keys(newErrors).length > 0) return;

    setPasswordSaving(true);

    try {
      await changePassword(currentPassword, newPassword);

      setPasswordSuccess("Password changed successfully.");

      setCurrentPassword("");
      setNewPassword("");
      setRetypePassword("");

      setErrors({});
    } catch (err) {
      const message =
        profileErrorMessages[err.code] ||
        "Failed to change password. Please try again.";

      setErrors((prev) => ({
        ...prev,
        form: message,
      }));
    } finally {
      setPasswordSaving(false);
    }
  }

  return (
    <DashboardLayout>
      <h1 className="page-title">My Profile</h1>

      <p className="page-subtitle">
        Manage your admin account details
      </p>

      {/* =================================================
          PROFILE CONTENT
          LEFT  = Profile Information + Username
          RIGHT = Change Password
          ================================================= */}
      <div className="profile-page-columns">

        {/* =========================
            LEFT COLUMN
            ========================= */}
        <div className="profile-col-left">

          {/* Profile Information */}
          <div className="profile-card profile-info-card">
            <div className="profile-avatar-row">
              <div className="profile-avatar">
                <FiUser />
              </div>

              <div className="profile-info-text">
                <div className="profile-name">
                  {originalUsername || "Admin"}
                </div>

                <div className="profile-email">
                  {email}
                </div>
              </div>
            </div>
          </div>

          {/* Username */}
          <div className="profile-card username-card">
            <h3 className="section-title">
              Username
            </h3>

            <form onSubmit={handleUsernameSave}>
              <div className="form-field">
                <label>Username</label>

                <input
                  type="text"
                  value={username}
                  onChange={(e) =>
                    setUsername(e.target.value)
                  }
                  className={
                    errors.username
                      ? "input-error"
                      : ""
                  }
                />

                {errors.username && (
                  <span className="field-error">
                    {errors.username}
                  </span>
                )}
              </div>

              {usernameSuccess && (
                <p className="success-msg">
                  {usernameSuccess}
                </p>
              )}

              <button
                type="submit"
                className="save-profile-btn"
                disabled={usernameSaving}
              >
                {usernameSaving
                  ? "Saving..."
                  : "Save Username"}
              </button>
            </form>
          </div>
        </div>

        {/* =========================
            RIGHT COLUMN
            ========================= */}
        <div className="profile-col-right">

          <div className="profile-card password-card">

            <h3 className="section-title">
              Change Password
            </h3>

            <form onSubmit={handlePasswordSave}>

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

              <div className="form-field">
                <label>Current Password</label>

                <div className="password-input-wrapper">
                  <input
                    type={showCurrentPassword ? "text" : "password"}
                    value={currentPassword}
                    onChange={(e) =>
                      setCurrentPassword(e.target.value)
                    }
                    className={
                      errors.currentPassword
                        ? "input-error"
                        : ""
                    }
                  />
                  <button
                    type="button"
                    className="toggle-password"
                    onClick={() => setShowCurrentPassword(!showCurrentPassword)}
                  >
                    {showCurrentPassword ? "Hide" : "Show"}
                  </button>
                </div>

                {errors.currentPassword && (
                  <span className="field-error">
                    {errors.currentPassword}
                  </span>
                )}
              </div>

              <div className="form-field">
                <label>New Password</label>

                <div className="password-input-wrapper">
                  <input
                    type={showNewPassword ? "text" : "password"}
                    value={newPassword}
                    onChange={(e) =>
                      setNewPassword(e.target.value)
                    }
                    className={
                      errors.newPassword
                        ? "input-error"
                        : ""
                    }
                  />
                  <button
                    type="button"
                    className="toggle-password"
                    onClick={() => setShowNewPassword(!showNewPassword)}
                  >
                    {showNewPassword ? "Hide" : "Show"}
                  </button>
                </div>

                {errors.newPassword && (
                  <span className="field-error">
                    {errors.newPassword}
                  </span>
                )}
              </div>

              <div className="form-field">
                <label>Retype New Password</label>

                <div className="password-input-wrapper">
                  <input
                    type={showRetypePassword ? "text" : "password"}
                    value={retypePassword}
                    onChange={(e) =>
                      setRetypePassword(e.target.value)
                    }
                    className={
                      errors.retypePassword
                        ? "input-error"
                        : ""
                    }
                  />
                  <button
                    type="button"
                    className="toggle-password"
                    onClick={() => setShowRetypePassword(!showRetypePassword)}
                  >
                    {showRetypePassword ? "Hide" : "Show"}
                  </button>
                </div>

                {errors.retypePassword && (
                  <span className="field-error">
                    {errors.retypePassword}
                  </span>
                )}
              </div>

              {errors.form && (
                <p className="form-error">
                  {errors.form}
                </p>
              )}

              {passwordSuccess && (
                <p className="success-msg">
                  {passwordSuccess}
                </p>
              )}

              <button
                type="submit"
                className="save-profile-btn"
                disabled={passwordSaving}
              >
                {passwordSaving
                  ? "Updating..."
                  : "Change Password"}
              </button>

            </form>
          </div>
        </div>

      </div>
    </DashboardLayout>
  );
}
import { useEffect, useState, useRef, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { signOut } from "firebase/auth";
import { auth } from "../firebase/firebase";
import { logActivity } from "../services/logService";
import { FiClock } from "react-icons/fi";
import "./SessionTimeoutManager.css";

// 15 minutes total inactivity allowed
const INACTIVITY_LIMIT_MS = 15 * 60 * 1000;
// Show warning 60 seconds before auto-logout (at 14 minutes)
const WARNING_BEFORE_LOGOUT_MS = 60 * 1000;
const STORAGE_KEY = "claro:last_activity";

export default function SessionTimeoutManager({ children }) {
  const navigate = useNavigate();
  const [showWarning, setShowWarning] = useState(false);
  const [secondsRemaining, setSecondsRemaining] = useState(60);

  const lastRecordedActivityRef = useRef(Date.now());
  const checkIntervalRef = useRef(null);

  const performLogout = useCallback(async (reason = "inactivity") => {
    setShowWarning(false);
    clearInterval(checkIntervalRef.current);

    const currentUser = auth.currentUser;
    if (currentUser) {
      try {
        await logActivity(
          "Admin Session Auto-Logout",
          currentUser.uid,
          "auth",
          "Logged out due to 15 minutes of inactivity",
          { reason, timeoutDuration: "15 minutes" }
        );
      } catch (err) {
        console.error("Failed to log timeout activity:", err);
      }
    }

    try {
      localStorage.removeItem(STORAGE_KEY);
      sessionStorage.clear();
      await signOut(auth);
    } catch (e) {
      console.error("Error signing out:", e);
    }

    navigate("/", {
      replace: true,
      state: {
        timeoutNotice:
          "You have been logged out after 15 minutes of inactivity for security.",
      },
    });
  }, [navigate]);

  const updateActivity = useCallback(() => {
    const now = Date.now();
    // Throttle writing to localStorage to once every 5 seconds
    if (now - lastRecordedActivityRef.current > 5000) {
      lastRecordedActivityRef.current = now;
      try {
        localStorage.setItem(STORAGE_KEY, now.toString());
      } catch (e) {
        // ignore localStorage quota errors
      }
    }
  }, []);

  const handleStayLoggedIn = useCallback(() => {
    const now = Date.now();
    lastRecordedActivityRef.current = now;
    try {
      localStorage.setItem(STORAGE_KEY, now.toString());
    } catch (e) {
      // ignore
    }
    setShowWarning(false);
    setSecondsRemaining(60);
  }, []);

  useEffect(() => {
    // Initialize current timestamp
    const now = Date.now();
    lastRecordedActivityRef.current = now;
    try {
      localStorage.setItem(STORAGE_KEY, now.toString());
    } catch (e) {
      // ignore
    }

    // Activity listeners
    const activityEvents = [
      "mousemove",
      "mousedown",
      "keydown",
      "touchstart",
      "scroll",
      "wheel",
    ];

    const onUserActivity = () => {
      // Only record activity if the warning dialog is not currently showing
      if (!showWarning) {
        updateActivity();
      }
    };

    activityEvents.forEach((evt) => {
      window.addEventListener(evt, onUserActivity, { passive: true });
    });

    // Cross-tab synchronization: if another tab is active, reset here too
    const onStorageChange = (e) => {
      if (e.key === STORAGE_KEY && e.newValue) {
        const remoteTime = parseInt(e.newValue, 10);
        if (!isNaN(remoteTime)) {
          lastRecordedActivityRef.current = remoteTime;
          setShowWarning(false);
          setSecondsRemaining(60);
        }
      }
    };
    window.addEventListener("storage", onStorageChange);

    // Periodic check every second
    checkIntervalRef.current = setInterval(() => {
      const currentTime = Date.now();
      let lastActivityTime = lastRecordedActivityRef.current;

      try {
        const stored = localStorage.getItem(STORAGE_KEY);
        if (stored) {
          const parsed = parseInt(stored, 10);
          if (!isNaN(parsed) && parsed > lastActivityTime) {
            lastActivityTime = parsed;
            lastRecordedActivityRef.current = parsed;
          }
        }
      } catch (e) {
        // ignore
      }

      const idleDuration = currentTime - lastActivityTime;

      if (idleDuration >= INACTIVITY_LIMIT_MS) {
        performLogout("inactivity");
      } else if (idleDuration >= INACTIVITY_LIMIT_MS - WARNING_BEFORE_LOGOUT_MS) {
        const remaining = Math.max(
          1,
          Math.ceil((INACTIVITY_LIMIT_MS - idleDuration) / 1000)
        );
        setShowWarning(true);
        setSecondsRemaining(remaining);
      } else {
        if (showWarning) {
          setShowWarning(false);
        }
      }
    }, 1000);

    return () => {
      activityEvents.forEach((evt) => {
        window.removeEventListener(evt, onUserActivity);
      });
      window.removeEventListener("storage", onStorageChange);
      if (checkIntervalRef.current) {
        clearInterval(checkIntervalRef.current);
      }
    };
  }, [showWarning, updateActivity, performLogout]);

  return (
    <>
      {children}

      {showWarning && (
        <div className="session-timeout-overlay" role="dialog" aria-modal="true">
          <div className="session-timeout-modal">
            <div className="session-timeout-icon">
              <FiClock />
            </div>
            <h3>Session Inactivity Warning</h3>
            <p>
              You have been inactive. For your security, your administrator
              session will be logged out automatically in:
            </p>

            <div className="session-countdown-badge">
              {secondsRemaining}s
            </div>

            <div className="session-timeout-actions">
              <button
                type="button"
                className="session-stay-btn"
                onClick={handleStayLoggedIn}
              >
                Stay Logged In
              </button>
              <button
                type="button"
                className="session-logout-btn"
                onClick={() => performLogout("manual_choice")}
              >
                Log Out Now
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}

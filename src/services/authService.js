import { signInWithEmailAndPassword, signOut, sendPasswordResetEmail } from "firebase/auth";
import { doc, getDoc, collection, query, where, getDocs, setDoc } from "firebase/firestore";
import { db, auth } from "../firebase/firebase";
import { logAuthEvent } from "./logService";

export const MAX_FAILED_ATTEMPTS = 5;
export const LOCKOUT_DURATION_MS = 15 * 60 * 1000; // 15 minutes

export const firebaseErrorMessages = {
  "auth/user-not-found": "Incorrect email or password.",
  "auth/wrong-password": "Incorrect email or password.",
  "auth/invalid-credential": "Incorrect email or password.",
  "auth/too-many-requests": "Too many login attempts. Please try again later.",
  "auth/network-request-failed": "Please check your internet connection.",
  "auth/user-disabled": "This administrator account has been disabled.",
  "auth/invalid-email": "Invalid email format.",
  "auth/missing-email": "Please enter your email address.",
  "auth/account-locked": "Account is temporarily locked due to 5 consecutive failed login attempts.",
};

function getEmailDocId(email) {
  return email.trim().toLowerCase().replace(/[^a-zA-Z0-9]/g, "_");
}

/**
 * Checks if the account associated with this email is currently locked out.
 */
export async function checkAccountLockout(email) {
  if (!email) return { isLocked: false };
  const docId = getEmailDocId(email);
  const now = Date.now();

  let lockedUntil = null;
  let attempts = 0;

  // 1. Try local storage first for immediate check
  try {
    const local = localStorage.getItem(`claro:lockout:${docId}`);
    if (local) {
      const parsed = JSON.parse(local);
      if (parsed?.lockedUntil && parsed.lockedUntil > now) {
        lockedUntil = parsed.lockedUntil;
        attempts = parsed.attempts || MAX_FAILED_ATTEMPTS;
      }
    }
  } catch (e) {
    // ignore
  }

  // 2. Check Firestore for cross-device synchronization
  try {
    const attemptRef = doc(db, "login_attempts", docId);
    const snap = await getDoc(attemptRef);
    if (snap.exists()) {
      const data = snap.data();
      if (data.lockedUntil && data.lockedUntil > now) {
        lockedUntil = Math.max(lockedUntil || 0, data.lockedUntil);
        attempts = Math.max(attempts, data.attempts || 0);
      }
    }
  } catch (e) {
    // fallback to local check
  }

  if (lockedUntil && lockedUntil > now) {
    const remainingMs = lockedUntil - now;
    return {
      isLocked: true,
      attempts,
      lockedUntil,
      remainingMinutes: Math.ceil(remainingMs / (60 * 1000)),
      remainingSeconds: Math.ceil(remainingMs / 1000),
    };
  }

  return { isLocked: false, attempts };
}

/**
 * Records a failed login attempt. Locks the account if limit reached.
 */
export async function recordFailedLogin(email) {
  if (!email) return;
  const docId = getEmailDocId(email);
  const now = Date.now();

  let currentAttempts = 0;
  try {
    const attemptRef = doc(db, "login_attempts", docId);
    const snap = await getDoc(attemptRef);
    if (snap.exists()) {
      const data = snap.data();
      // If previous lockout already expired, reset counter
      if (!data.lockedUntil || data.lockedUntil <= now) {
        currentAttempts = data.attempts || 0;
      }
    }
  } catch (e) {
    // local fallback
    try {
      const local = localStorage.getItem(`claro:lockout:${docId}`);
      if (local) {
        const parsed = JSON.parse(local);
        if (!parsed.lockedUntil || parsed.lockedUntil <= now) {
          currentAttempts = parsed.attempts || 0;
        }
      }
    } catch (err) {
      // ignore
    }
  }

  const newAttempts = currentAttempts + 1;
  const isNowLocked = newAttempts >= MAX_FAILED_ATTEMPTS;
  const lockedUntil = isNowLocked ? now + LOCKOUT_DURATION_MS : null;

  const payload = {
    email: email.trim().toLowerCase(),
    attempts: newAttempts,
    lockedUntil,
    lastAttempt: now,
  };

  // Update local storage
  try {
    localStorage.setItem(`claro:lockout:${docId}`, JSON.stringify(payload));
  } catch (e) {
    // ignore
  }

  // Update Firestore
  try {
    const attemptRef = doc(db, "login_attempts", docId);
    await setDoc(attemptRef, payload, { merge: true });
  } catch (e) {
    console.warn("Firestore lockout record warning:", e);
  }

  // Tamper-proof audit logging
  if (isNowLocked) {
    await logAuthEvent("Account Locked", email, {
      reason: "5 consecutive failed login attempts",
      duration: "15 minutes",
      lockedUntil: new Date(lockedUntil).toISOString(),
    });
  } else {
    await logAuthEvent("Failed Login Attempt", email, {
      attemptCount: newAttempts,
      remainingAttempts: MAX_FAILED_ATTEMPTS - newAttempts,
    });
  }

  return {
    isLocked: isNowLocked,
    attempts: newAttempts,
    remainingAttempts: Math.max(0, MAX_FAILED_ATTEMPTS - newAttempts),
    remainingMinutes: isNowLocked ? 15 : 0,
  };
}

/**
 * Resets failed attempts after successful sign in.
 */
export async function resetFailedLogins(email) {
  if (!email) return;
  const docId = getEmailDocId(email);
  try {
    localStorage.removeItem(`claro:lockout:${docId}`);
  } catch (e) {
    // ignore
  }

  try {
    const attemptRef = doc(db, "login_attempts", docId);
    await setDoc(
      attemptRef,
      { attempts: 0, lockedUntil: null, lastSuccess: Date.now() },
      { merge: true }
    );
  } catch (e) {
    // ignore
  }
}

export async function loginAdmin(email, password) {
  const normalizedEmail = email.trim().toLowerCase();

  // 1. Check account lockout state before attempting sign-in
  const lockout = await checkAccountLockout(normalizedEmail);
  if (lockout.isLocked) {
    throw {
      code: "auth/account-locked",
      remainingMinutes: lockout.remainingMinutes,
      lockedUntil: lockout.lockedUntil,
    };
  }

  // 2. Authenticate with Firebase
  let userCredential;
  try {
    userCredential = await signInWithEmailAndPassword(auth, normalizedEmail, password);
  } catch (err) {
    // Record failed attempt for credential errors
    if (
      err.code === "auth/wrong-password" ||
      err.code === "auth/invalid-credential" ||
      err.code === "auth/user-not-found"
    ) {
      const result = await recordFailedLogin(normalizedEmail);
      if (result.isLocked) {
        throw {
          code: "auth/account-locked",
          remainingMinutes: result.remainingMinutes,
          lockedUntil: Date.now() + LOCKOUT_DURATION_MS,
        };
      }
      throw {
        ...err,
        attempts: result.attempts,
        remainingAttempts: result.remainingAttempts,
      };
    }
    throw err;
  }

  const user = userCredential.user;

  // 3. Reset failed login attempts upon successful credential match
  await resetFailedLogins(normalizedEmail);

  // 4. Verify admin role in "admins" collection
  const adminRef = doc(db, "admins", user.uid);
  let adminSnap = await getDoc(adminRef);
  let adminData = null;

  if (!adminSnap.exists()) {
    try {
      const q = query(collection(db, "admins"), where("email", "==", user.email));
      const qSnap = await getDocs(q);

      if (qSnap.empty) {
        await signOut(auth);
        await logAuthEvent("Unauthorized Admin Login Attempt", normalizedEmail, {
          reason: "Not found in admins collection",
        });
        throw { code: "not-admin" };
      }

      const existing = qSnap.docs[0];
      adminData = existing.data();

      try {
        await setDoc(adminRef, adminData);
      } catch (e) {
        // ignore
      }
    } catch (e) {
      await signOut(auth);
      throw { code: "not-admin" };
    }
  } else {
    adminData = adminSnap.data();
  }

  if (adminData.active === false) {
    await signOut(auth);
    await logAuthEvent("Disabled Admin Login Attempt", normalizedEmail, {
      reason: "Account marked inactive",
    });
    throw { code: "auth/user-disabled" };
  }

  // Log successful admin authentication
  await logAuthEvent("Admin Login Success", normalizedEmail, {
    uid: user.uid,
    adminName: adminData.name || user.email,
  });

  return { uid: user.uid, ...adminData };
}

export async function resetPassword(email) {
  if (!email) throw { code: "auth/missing-email" };
  await sendPasswordResetEmail(auth, email);
}
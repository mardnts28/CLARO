import {
  collection,
  addDoc,
  getDocs,
  query,
  orderBy,
  limit,
  Timestamp,
  doc,
  getDoc,
} from "firebase/firestore";
import { db, auth } from "../firebase/firebase";

let cachedIpAddress = null;

/**
 * Fetches the client's public IP address with caching.
 * Uses ipify API with fallback to Cloudflare cdn-cgi/trace.
 */
export async function getClientIpAddress() {
  if (cachedIpAddress) return cachedIpAddress;

  try {
    const sessionCached = sessionStorage.getItem("claro:client_ip");
    if (sessionCached) {
      cachedIpAddress = sessionCached;
      return cachedIpAddress;
    }
  } catch (e) {
    // ignore sessionStorage access errors
  }

  try {
    const response = await fetch("https://api.ipify.org?format=json", {
      signal: AbortSignal.timeout(3000),
    });
    if (response.ok) {
      const data = await response.json();
      if (data?.ip) {
        cachedIpAddress = data.ip;
        try {
          sessionStorage.setItem("claro:client_ip", data.ip);
        } catch (e) {
          // ignore
        }
        return cachedIpAddress;
      }
    }
  } catch (e) {
    // try fallback
  }

  try {
    const cfTrace = await fetch("https://cloudflare.com/cdn-cgi/trace", {
      signal: AbortSignal.timeout(2000),
    });
    if (cfTrace.ok) {
      const text = await cfTrace.text();
      const match = text.match(/ip=([^\n]+)/);
      if (match && match[1]) {
        cachedIpAddress = match[1];
        return cachedIpAddress;
      }
    }
  } catch (e) {
    // ignore
  }

  cachedIpAddress = "Internal / Unknown";
  return cachedIpAddress;
}

/**
 * Tamper-Proof Audit Logger:
 * Records administrator actions, exact timestamp, IP address, user agent,
 * and specific field changes made.
 */
export async function logActivity(
  activity,
  targetId,
  type = "report",
  label = "",
  changes = null
) {
  const user = auth.currentUser;
  let adminName = user?.email || "Unknown Admin";

  try {
    if (user?.uid) {
      const adminDoc = await getDoc(doc(db, "admins", user.uid));
      if (adminDoc.exists()) {
        const data = adminDoc.data();
        if (data?.name) adminName = data.name;
      }
    }
  } catch (e) {
    // fallback to email
  }

  const ipAddress = await getClientIpAddress();
  const userAgent = typeof navigator !== "undefined" ? navigator.userAgent : "Unknown";

  const logPayload = {
    activity,
    targetId: targetId || "system",
    type,
    label: label || "",
    adminUid: user?.uid || "unauthenticated",
    adminName,
    ipAddress,
    userAgent,
    timestamp: Timestamp.now(),
  };

  if (changes && typeof changes === "object") {
    logPayload.changes = changes;
  }

  try {
    await addDoc(collection(db, "activity_logs"), logPayload);
  } catch (err) {
    console.warn("Audit log write notice:", err);
  }
}

/**
 * Special logger for Auth events (logins, failed attempts, lockouts, logouts)
 */
export async function logAuthEvent(activity, email, details = {}) {
  const ipAddress = await getClientIpAddress();
  const userAgent = typeof navigator !== "undefined" ? navigator.userAgent : "Unknown";

  try {
    await addDoc(collection(db, "activity_logs"), {
      activity,
      targetId: email || "auth",
      type: "auth",
      label: email || "Anonymous",
      adminUid: auth.currentUser?.uid || "unauthenticated",
      adminName: email || "System Auth",
      ipAddress,
      userAgent,
      changes: details,
      timestamp: Timestamp.now(),
    });
  } catch (err) {
    console.warn("Auth audit log write notice:", err);
  }
}

/**
 * Reads audit logs ordered by newest first.
 */
export async function getActivityLogs(count = 20) {
  const q = query(
    collection(db, "activity_logs"),
    orderBy("timestamp", "desc"),
    limit(count)
  );
  const snapshot = await getDocs(q);
  return snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
}
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

export async function logActivity(activity, targetId, type = "report", label = "") {
  const user = auth.currentUser;

  // Try to read the admin's display name from their admin profile (allowed
  // for the signed-in user). Fall back to the auth email if not available.
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
    // ignore and fall back to email
  }

  await addDoc(collection(db, "activity_logs"), {
    activity,
    targetId,
    type,
    label, // human-readable reference (product name or review snippet)
    adminUid: user?.uid || "unknown",
    adminName,
    timestamp: Timestamp.now(),
  });
}
export async function getActivityLogs(count = 20) {
  const q = query(
    collection(db, "activity_logs"),
    orderBy("timestamp", "desc"),
    limit(count)
  );
  const snapshot = await getDocs(q);
  return snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
}
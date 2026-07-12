import {
  collection,
  addDoc,
  getDocs,
  query,
  orderBy,
  limit,
  Timestamp,
} from "firebase/firestore";
import { db, auth } from "../firebase/firebase";

export async function logActivity(activity, targetId, type = "report") {
  const user = auth.currentUser;

  await addDoc(collection(db, "activity_logs"), {
    activity,
    targetId,
    type, // "report" | "review"
    adminUid: user?.uid || "unknown",
    adminName: user?.email || "Unknown Admin",
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
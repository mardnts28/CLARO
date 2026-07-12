import {
  collection,
  getDocs,
  doc,
  getDoc,
  updateDoc,
  deleteDoc,
  Timestamp,
} from "firebase/firestore";
import { db } from "../firebase/firebase";
import { logActivity } from "./logService";

export async function getAllReviews() {
  const snapshot = await getDocs(collection(db, "suhestiyon"));
  return snapshot.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      ...data,
      status: data.status || "New", // default if field doesn't exist yet
    };
  });
}

export async function getReviewById(reviewId) {
  const ref = doc(db, "suhestiyon", reviewId);
  const snap = await getDoc(ref);
  if (!snap.exists()) throw { code: "review/not-found" };

  await logActivity("Viewed Review", reviewId);

  const data = snap.data();
  return { id: snap.id, ...data, status: data.status || "New" };
}

export async function updateReviewStatus(reviewId, status) {
  const ref = doc(db, "suhestiyon", reviewId);
  await updateDoc(ref, { status });
  await logActivity(`Marked Review as ${status}`, reviewId);
}

export async function replyToReview(reviewId, replyText) {
  const ref = doc(db, "suhestiyon", reviewId);
  await updateDoc(ref, {
    adminReply: replyText,
    repliedAt: Timestamp.now(),
  });
  await logActivity("Replied to Review", reviewId);
}

export async function deleteReview(reviewId) {
  const ref = doc(db, "suhestiyon", reviewId);
  await deleteDoc(ref);
  await logActivity("Deleted Review", reviewId);
}
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

export async function getReviewStats() {
  const reviews = await getAllReviews();
  const totalReviews = reviews.length;
  const newReviews = reviews.filter((r) => r.status === "New").length;
  return { totalReviews, newReviews };
}

export async function getReviewById(reviewId) {
  const ref = doc(db, "suhestiyon", reviewId);
  const snap = await getDoc(ref);
  if (!snap.exists()) throw { code: "review/not-found" };

  const data = snap.data();
  const label = data.text?.slice(0, 40) || data.userName;
  await logActivity("Viewed Review", reviewId, "review", label);

  return { id: snap.id, ...data, status: data.status || "New" };
}

export async function updateReviewStatus(reviewId, status) {
  const ref = doc(db, "suhestiyon", reviewId);
  const snap = await getDoc(ref);
  const data = snap.exists() ? snap.data() : {};
  const label = data.text?.slice(0, 40) || data.userName;

  await updateDoc(ref, { status });
  await logActivity(`Marked Review as ${status}`, reviewId, "review", label);
}

export async function replyToReview(reviewId, replyText) {
  const ref = doc(db, "suhestiyon", reviewId);
  const snap = await getDoc(ref);
  const data = snap.exists() ? snap.data() : {};
  const label = data.text?.slice(0, 40) || data.userName;

  await updateDoc(ref, {
    adminReply: replyText,
    repliedAt: Timestamp.now(),
  });
  await logActivity("Replied to Review", reviewId, "review", label);
}

export async function deleteReview(reviewId) {
  const ref = doc(db, "suhestiyon", reviewId);
  const snap = await getDoc(ref);
  const data = snap.exists() ? snap.data() : {};
  const label = data.text?.slice(0, 40) || data.userName;

  await deleteDoc(ref);
  await logActivity("Deleted Review", reviewId, "review", label);
}
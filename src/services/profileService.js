import { doc, updateDoc } from "firebase/firestore";
import {
  EmailAuthProvider,
  reauthenticateWithCredential,
  updatePassword,
} from "firebase/auth";
import { db, auth } from "../firebase/firebase";
import { logActivity } from "./logService";

export async function updateUsername(uid, newName) {
  const ref = doc(db, "admins", uid);
  await updateDoc(ref, { name: newName });
  await logActivity("Updated Username", uid, "profile");
}

export async function changePassword(currentPassword, newPassword) {
  const user = auth.currentUser;
  if (!user) throw { code: "auth/no-user" };

  // Re-authenticate first — Firebase requires this for sensitive changes
  const credential = EmailAuthProvider.credential(user.email, currentPassword);
  await reauthenticateWithCredential(user, credential);

  await updatePassword(user, newPassword);
  await logActivity("Changed Password", user.uid, "profile");
}

export const profileErrorMessages = {
  "auth/wrong-password": "Current password is incorrect.",
  "auth/invalid-credential": "Current password is incorrect.",
  "auth/weak-password": "New password is too weak (minimum 6 characters).",
  "auth/requires-recent-login": "Please log out and log in again before changing your password.",
  "auth/too-many-requests": "Too many attempts. Please try again later.",
  "auth/no-user": "No admin is currently signed in.",
};
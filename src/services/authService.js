import { signInWithEmailAndPassword, signOut, sendPasswordResetEmail } from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import { auth, db } from "../firebase/firebase";

export const firebaseErrorMessages = {
  "auth/user-not-found": "No administrator account found.",
  "auth/wrong-password": "Incorrect email or password.",
  "auth/invalid-credential": "Incorrect email or password.",
  "auth/too-many-requests": "Too many login attempts. Please try again later.",
  "auth/network-request-failed": "Please check your internet connection.",
  "auth/user-disabled": "This administrator account has been disabled.",
  "auth/invalid-email": "Invalid email format.",
  "auth/missing-email": "Please enter your email address.",
};

export async function loginAdmin(email, password) {
  // 1. Authenticate with Firebase
  const userCredential = await signInWithEmailAndPassword(auth, email, password);
  const user = userCredential.user;

  // 2. Check if this uid exists in the "admins" collection
  const adminRef = doc(db, "admins", user.uid);
  const adminSnap = await getDoc(adminRef);

  if (!adminSnap.exists()) {
    await signOut(auth); // not an admin, kick them out immediately
    throw { code: "not-admin" };
  }

  const adminData = adminSnap.data();

  if (adminData.active === false) {
    await signOut(auth);
    throw { code: "auth/user-disabled" };
  }

  return { uid: user.uid, ...adminData };
}

export async function resetPassword(email) {
  if (!email) throw { code: "auth/missing-email" };
  await sendPasswordResetEmail(auth, email);
}
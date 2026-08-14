import { signInWithEmailAndPassword, signOut, sendPasswordResetEmail } from "firebase/auth";
import { doc, getDoc, collection, query, where, getDocs, setDoc } from "firebase/firestore";
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
  let adminSnap = await getDoc(adminRef);
  let adminData = null;

  if (!adminSnap.exists()) {
    // Fallback: some projects add the admin document using a different ID
    // (for example an auto-id or the email). Try finding by email and
    // migrate/create a UID-keyed document so future logins succeed.
    try {
      const q = query(collection(db, "admins"), where("email", "==", user.email));
      const qSnap = await getDocs(q);

      if (qSnap.empty) {
        await signOut(auth); // not an admin, kick them out
        throw { code: "not-admin" };
      }

      const existing = qSnap.docs[0];
      adminData = existing.data();

      // Create a UID-keyed admin doc for consistency
      try {
        await setDoc(adminRef, adminData);
      } catch (e) {
        // If creating the doc fails, ignore and continue using adminData
      }
    } catch (e) {
      // Likely a Firestore permission error (security rules block reading
      // other admins documents). Treat as "not an admin" so the UI shows
      // a clear unauthorized message rather than a generic failure.
      await signOut(auth);
      throw { code: "not-admin" };
    }
  } else {
    adminData = adminSnap.data();
  }

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
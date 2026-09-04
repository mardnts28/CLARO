import { Navigate } from "react-router-dom";
import { useEffect, useState } from "react";
import { onAuthStateChanged, signOut } from "firebase/auth";
import { auth, db } from "../firebase/firebase";
import { doc, getDoc, collection, query, where, getDocs, setDoc } from "firebase/firestore";

export default function ProtectedRoute({ children }) {
  const [checking, setChecking] = useState(true);
  const [isAuthed, setIsAuthed] = useState(false);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (user) => {
      if (!user) {
        setIsAuthed(false);
        setChecking(false);
        return;
      }

      try {
        if (sessionStorage.getItem(`claro:otp-verified:${user.uid}`) !== "true") {
          await signOut(auth);
          setIsAuthed(false);
          setChecking(false);
          return;
        }

        const adminRef = doc(db, "admins", user.uid);
        let adminSnap = await getDoc(adminRef);

        if (!adminSnap.exists()) {
          // Fallback: try finding an admin document by email and migrate it
          const q = query(collection(db, "admins"), where("email", "==", user.email));
          const qSnap = await getDocs(q);

          if (qSnap.empty) {
            await signOut(auth);
            setIsAuthed(false);
            setChecking(false);
            return;
          }

          const existing = qSnap.docs[0];
          const adminData = existing.data();

          // Create a UID-keyed admin doc for consistency
          try {
            await setDoc(adminRef, adminData);
            adminSnap = await getDoc(adminRef);
          } catch (e) {
            // ignore and use adminData directly
            adminSnap = { exists: () => true, data: () => adminData };
          }
        }

        const data = adminSnap.data();
        if (data.active === false) {
          await signOut(auth);
          setIsAuthed(false);
        } else {
          setIsAuthed(true);
        }
      } catch (e) {
        await signOut(auth);
        setIsAuthed(false);
      } finally {
        setChecking(false);
      }
    });

    return unsub;
  }, []);

  if (checking) return <p>Loading...</p>;
  if (!isAuthed) return <Navigate to="/" replace />;

  return children;
}
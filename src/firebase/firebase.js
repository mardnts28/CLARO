import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";
import { getAuth } from "firebase/auth";

// Firebase configuration from environment variables
const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY || "AIzaSyD3Uv5V78zCqi66yTjj3a5DUNsKRRnj1qk",
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || "claro-e90dd.firebaseapp.com",
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID || "claro-e90dd",
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET || "claro-e90dd.firebasestorage.app",
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID || "1033502181973",
  appId: import.meta.env.VITE_FIREBASE_APP_ID || "1:1033502181973:web:91e1da13e5cdfb01ff22dc",
  measurementId: import.meta.env.VITE_FIREBASE_MEASUREMENT_ID || "G-WLX4JJSPFC"
};

const app = initializeApp(firebaseConfig);

export const db = getFirestore(app);
export const auth = getAuth(app);
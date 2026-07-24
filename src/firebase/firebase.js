import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";
import { getAuth } from "firebase/auth";

const firebaseConfig = {
  apiKey: "AIzaSyD3Uv5V78zCqi66yTjj3a5DUNsKRRnj1qk",
  authDomain: "claro-e90dd.firebaseapp.com",
  projectId: "claro-e90dd",
  storageBucket: "claro-e90dd.firebasestorage.app",
  messagingSenderId: "1033502181973",
  appId: "1:1033502181973:web:91e1da13e5cdfb01ff22dc",
  measurementId: "G-WLX4JJSPFC"
};

const app = initializeApp(firebaseConfig);

export const db = getFirestore(app);
export const auth = getAuth(app);
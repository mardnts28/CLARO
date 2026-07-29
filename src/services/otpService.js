import { doc, setDoc, getDoc, deleteDoc, Timestamp } from "firebase/firestore";
import { db } from "../firebase/firebase";
import emailjs from "@emailjs/browser";

export const OTP_EXPIRY_MINUTES = 5;
const MAX_ATTEMPTS = 5;

// EmailJS config — from https://www.emailjs.com dashboard
const EMAILJS_SERVICE_ID = "service_5y6zi4d";
const EMAILJS_TEMPLATE_ID = "template_aarxuyn";
const EMAILJS_PUBLIC_KEY = "wJyfTyTAuJIC6XQvn";

function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

export async function generateAndSendOTP(uid, email) {
  const otp = generateOTP();
  const expiresAt = Timestamp.fromDate(
    new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000)
  );

  try {
    await setDoc(doc(db, "otps", uid), {
      otp,
      expiresAt,
      attempts: 0,
      verified: false,
    });
    console.log("✅ Firestore OTP doc written successfully");
  } catch (err) {
    console.error("❌ FIRESTORE WRITE FAILED:", err);
    throw err;
  }

  try {
    await emailjs.send(
      EMAILJS_SERVICE_ID,
      EMAILJS_TEMPLATE_ID,
      {
        to_email: email,
        otp_code: otp,
      },
      EMAILJS_PUBLIC_KEY
    );
    console.log("✅ Email sent successfully");
  } catch (err) {
    console.error("❌ EMAILJS SEND FAILED:", err);
    throw err;
  }

  // Return the expiry so the UI can show a live countdown timer
  return { expiresAt: expiresAt.toDate() };
}

export async function verifyOTP(uid, enteredOTP) {
  const otpRef = doc(db, "otps", uid);
  const otpSnap = await getDoc(otpRef);

  if (!otpSnap.exists()) {
    throw { code: "otp/not-found" };
  }

  const data = otpSnap.data();

  if (data.attempts >= MAX_ATTEMPTS) {
    await deleteDoc(otpRef);
    throw { code: "otp/too-many-attempts" };
  }

  if (data.expiresAt.toDate() < new Date()) {
    await deleteDoc(otpRef);
    throw { code: "otp/expired" };
  }

  if (data.otp !== enteredOTP) {
    await setDoc(otpRef, { ...data, attempts: data.attempts + 1 }, { merge: true });
    throw { code: "otp/incorrect" };
  }

  await deleteDoc(otpRef); // single use
  return true;
}

export const otpErrorMessages = {
  "otp/not-found": "OTP session not found. Please log in again.",
  "otp/expired": "OTP expired. Please request a new one.",
  "otp/incorrect": "Incorrect OTP.",
  "otp/too-many-attempts": "Too many incorrect attempts. Please request a new OTP.",
};
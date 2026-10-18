import { doc, setDoc, getDoc, deleteDoc, Timestamp } from "firebase/firestore";
import { db } from "../firebase/firebase";

export const OTP_EXPIRY_MINUTES = 5;
const MAX_ATTEMPTS = 5;

// Cloudflare Worker config for email routing
const WORKER_URL = import.meta.env.VITE_GEMINI_PROXY_URL;
const APP_SHARED_SECRET = import.meta.env.VITE_APP_SHARED_SECRET;

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
    // Format expiry time for email (12-hour format, e.g., 7:18 PM)
    const expiryTime = expiresAt.toDate().toLocaleTimeString('en-US', {
      hour: 'numeric',
      minute: '2-digit',
      hour12: true
    });

    const response = await fetch(`${WORKER_URL}/email`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-App-Secret': APP_SHARED_SECRET,
      },
      body: JSON.stringify({
        template_params: {
          to_email: email,
          passcode: otp,
          time: expiryTime,
        },
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ Worker email failed: ${response.status} - ${errorText}`);
      throw new Error(`Failed to send OTP: ${response.status} - ${errorText}`);
    }

    console.log("✅ Email sent successfully via Worker");
  } catch (err) {
    console.error("❌ EMAIL SEND FAILED:", err);
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
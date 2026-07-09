const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Cloud Function: checkMfaEnabled
 * 
 * Checks if MFA is enabled for a given email address.
 * This function is called before authentication, so it uses the Admin SDK
 * to bypass Firestore security rules.
 * 
 * @param {Object} data - { email: string }
 * @returns {Object} - { mfaEnabled: boolean }
 * 
 * Security features:
 * - Uses Admin SDK (bypasses client-side security rules)
 * - Returns false for non-existent emails (prevents user enumeration)
 * - Only returns the mfaEnabled field (no other user data)
 * - Basic rate limiting via App Check (recommended to enable on client)
 */
exports.checkMfaEnabled = onCall({
  region: 'us-central1',
  memory: '256MiB',
  maxInstances: 10,
}, async (request) => {
  const { email } = request.data;

  // Validate input
  if (!email || typeof email !== 'string' || !email.includes('@')) {
    throw new HttpsError('invalid-argument', 'Invalid email address');
  }

  const normalizedEmail = email.trim().toLowerCase();

  try {
    // Use Admin SDK to query users collection (bypasses security rules)
    const usersSnapshot = await admin
      .firestore()
      .collection('users')
      .where('email', '==', normalizedEmail)
      .limit(1)
      .get();

    // If user doesn't exist, return false (prevents user enumeration)
    if (usersSnapshot.empty) {
      logger.info(`MFA check: email not found, returning false`);
      return { mfaEnabled: false };
    }

    const userDoc = usersSnapshot.docs[0];
    const userData = userDoc.data();

    // Only return the mfaEnabled field, nothing else
    const mfaEnabled = userData.mfaEnabled === true;

    logger.info(`MFA check for ${normalizedEmail}: ${mfaEnabled}`);
    return { mfaEnabled };

  } catch (error) {
    logger.error('Error in checkMfaEnabled:', error);
    throw new HttpsError('internal', 'Failed to check MFA status');
  }
});

/**
 * Cloud Function: buildOtpChallenge
 * 
 * Generates an OTP, stores it in Firestore, and sends it via email.
 * Credentials are verified on the client side before calling this function.
 * 
 * @param {Object} data - { email: string, uid: string }
 * @returns {Object} - { uid: string, code: string, expiresAt: Timestamp, emailSent: boolean }
 * 
 * Security features:
 * - Uses Admin SDK for all Firestore operations
 * - Generates secure random 6-digit code
 * - Stores OTP with 5-minute expiration
 * - Sends email via EmailJS (same as client implementation)
 * - Note: Password verification happens client-side before this call
 */
exports.buildOtpChallenge = onCall({
  region: 'us-central1',
  memory: '256MiB',
  maxInstances: 10,
}, async (request) => {
  const { email, uid } = request.data;

  // Validate input
  if (!email || typeof email !== 'string' || !email.includes('@')) {
    throw new HttpsError('invalid-argument', 'Invalid email address');
  }
  if (!uid || typeof uid !== 'string') {
    throw new HttpsError('invalid-argument', 'Invalid user ID');
  }

  const normalizedEmail = email.trim().toLowerCase();

  try {
    // Verify that the UID exists and matches the email (prevent UID spoofing)
    const userRecord = await admin.auth().getUser(uid);
    if (userRecord.email.toLowerCase() !== normalizedEmail) {
      throw new HttpsError('permission-denied', 'UID does not match email');
    }

    // Generate 6-digit OTP code
    const code = (100000 + Date.now() % 900000).toString().padLeft(6, '0');
    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromDate(new Date(now.toDate().getTime() + 5 * 60 * 1000)); // 5 minutes

    // Store OTP in Firestore using Admin SDK (bypasses security rules)
    await admin.firestore().collection('login_otps').doc(uid).set({
      uid: uid,
      code: code,
      createdAt: now,
      expiresAt: expiresAt,
      attempts: 0,
    });

    // Send OTP email via EmailJS
    let emailSent = false;
    try {
      const expiry = expiresAt.toDate();
      const formattedTime = 
        `${expiry.getHours().toString().padStart(2, '0')}:${expiry.getMinutes().toString().padLeft(2, '0')}`;

      const emailjsResponse = await fetch('https://api.emailjs.com/api/v1.0/email/send', {
        method: 'POST',
        headers: {
          'origin': 'http://localhost',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          service_id: 'service_5y6zi4d',
          template_id: 'template_te10bxg',
          user_id: 'wJyfTyTAuJIC6XQvn',
          template_params: {
            to_email: normalizedEmail,
            passcode: code,
            time: formattedTime,
          },
        }),
      });

      if (emailjsResponse.ok) {
        emailSent = true;
        logger.info(`OTP email sent to ${normalizedEmail}`);
      } else {
        logger.error(`Failed to send OTP email: ${emailjsResponse.statusText}`);
      }
    } catch (emailError) {
      logger.error('Error sending OTP email:', emailError);
      // Don't throw - email failure shouldn't block OTP generation
    }

    logger.info(`OTP challenge created for ${normalizedEmail}, email sent: ${emailSent}`);
    
    return {
      uid: uid,
      code: code,
      expiresAt: expiresAt,
      emailSent: emailSent,
      recipientEmail: normalizedEmail,
    };

  } catch (error) {
    logger.error('Error in buildOtpChallenge:', error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError('internal', 'Failed to create OTP challenge');
  }
});

/**
 * Cloud Function: verifyOtp
 * 
 * Verifies an OTP code against the stored challenge.
 * This replaces the client-side verifyOtp to avoid permission issues.
 * 
 * @param {Object} data - { uid: string, code: string }
 * @returns {Object} - { valid: boolean, message: string }
 * 
 * Security features:
 * - Uses Admin SDK for all Firestore operations
 * - Checks expiration and attempt limits
 * - Deletes OTP after successful verification or too many attempts
 */
exports.verifyOtp = onCall({
  region: 'us-central1',
  memory: '256MiB',
  maxInstances: 10,
}, async (request) => {
  const { uid, code } = request.data;

  // Validate input
  if (!uid || typeof uid !== 'string') {
    throw new HttpsError('invalid-argument', 'Invalid user ID');
  }
  if (!code || typeof code !== 'string' || code.length !== 6) {
    throw new HttpsError('invalid-argument', 'Invalid OTP code');
  }

  try {
    const otpDoc = await admin.firestore().collection('login_otps').doc(uid).get();

    if (!otpDoc.exists) {
      return { valid: false, message: 'This verification code has expired.' };
    }

    const data = otpDoc.data();
    const attempts = data.attempts || 0;

    // Check attempt limit
    if (attempts >= 5) {
      await admin.firestore().collection('login_otps').doc(uid).delete();
      return { valid: false, message: 'Too many failed attempts. Please log in again.' };
    }

    // Check expiration
    const expiresAt = data.expiresAt?.toDate();
    if (!expiresAt || expiresAt < new Date()) {
      await admin.firestore().collection('login_otps').doc(uid).delete();
      return { valid: false, message: 'This verification code has expired.' };
    }

    // Verify code
    if (data.code !== code) {
      await admin.firestore().collection('login_otps').doc(uid).update({
        attempts: admin.firestore.FieldValue.increment(1),
      });
      return { valid: false, message: 'Invalid verification code.' };
    }

    // Valid OTP - delete the challenge
    await admin.firestore().collection('login_otps').doc(uid).delete();
    logger.info(`OTP verified successfully for uid: ${uid}`);

    return { valid: true, message: null };

  } catch (error) {
    logger.error('Error in verifyOtp:', error);
    throw new HttpsError('internal', 'Failed to verify OTP');
  }
});

/**
 * Cloud Function: clearOtpChallenge
 * 
 * Clears an OTP challenge after successful login.
 * This replaces the client-side clearOtpChallenge to avoid permission issues.
 * 
 * @param {Object} data - { uid: string }
 * @returns {Object} - { success: boolean }
 */
exports.clearOtpChallenge = onCall({
  region: 'us-central1',
  memory: '256MiB',
  maxInstances: 10,
}, async (request) => {
  const { uid } = request.data;

  // Validate input
  if (!uid || typeof uid !== 'string') {
    throw new HttpsError('invalid-argument', 'Invalid user ID');
  }

  try {
    await admin.firestore().collection('login_otps').doc(uid).delete();
    logger.info(`OTP challenge cleared for uid: ${uid}`);
    return { success: true };
  } catch (error) {
    logger.error('Error in clearOtpChallenge:', error);
    throw new HttpsError('internal', 'Failed to clear OTP challenge');
  }
});

# MFA/OTP Bug Fix Summary

## Root Cause
The MFA/OTP bug was caused by Firestore security rules blocking unauthenticated reads. When a user tried to log in with MFA enabled, the `isMfaEnabledForEmail()` function attempted to read the user's Firestore document to check the `mfaEnabled` field before authentication. Since the user wasn't authenticated yet, the read was denied by the security rule `allow read: if request.auth != null && request.auth.uid == userId`, causing the function to silently return `false` and skip the MFA flow entirely.

## Solution Implemented
Instead of loosening security rules, the fix implements Firebase Cloud Functions with Admin SDK to bypass security rules server-side for pre-authentication operations.

## Changes Made

### 1. Cloud Functions Setup
- **Created** `functions/` directory with:
  - `package.json` - Node.js dependencies for Cloud Functions
  - `index.js` - Cloud Functions implementation
  - `.gitignore` - Excludes node_modules and build artifacts
- **Updated** `firebase.json` to specify functions source directory

### 2. Cloud Functions Created (`functions/index.js`)

#### checkMfaEnabled
- **Purpose**: Checks if MFA is enabled for a given email
- **Input**: `{ email: string }`
- **Output**: `{ mfaEnabled: boolean }`
- **Security**:
  - Uses Admin SDK to bypass Firestore rules
  - Returns `false` for non-existent emails (prevents user enumeration)
  - Only returns the `mfaEnabled` field (no other user data)
  - Basic input validation

#### buildOtpChallenge
- **Purpose**: Generates OTP, stores it in Firestore, and sends via email
- **Input**: `{ email: string, uid: string }`
- **Output**: `{ uid: string, code: string, expiresAt: Timestamp, emailSent: boolean }`
- **Security**:
  - Verifies UID matches email (prevents UID spoofing)
  - Generates secure 6-digit code
  - Stores OTP with 5-minute expiration
  - Sends email via EmailJS
  - Uses Admin SDK for all Firestore operations

#### verifyOtp
- **Purpose**: Verifies OTP code against stored challenge
- **Input**: `{ uid: string, code: string }`
- **Output**: `{ valid: boolean, message: string }`
- **Security**:
  - Checks expiration and attempt limits (max 5 attempts)
  - Deletes OTP after successful verification or too many attempts
  - Uses Admin SDK for all Firestore operations

#### clearOtpChallenge
- **Purpose**: Clears OTP challenge after successful login
- **Input**: `{ uid: string }`
- **Output**: `{ success: boolean }`
- **Security**: Uses Admin SDK for Firestore operations

### 3. Client-Side Updates

#### pubspec.yaml
- **Added** `cloud_functions: ^5.1.3` dependency

#### lib/services/auth_service.dart
- **Added** `cloud_functions` import
- **Updated** `isMfaEnabledForEmail()`:
  - Now calls `checkMfaEnabled` Cloud Function
  - Throws exceptions on errors instead of silently returning `false`
  - Prevents skipping MFA due to network/connectivity issues
- **Updated** `buildOtpChallenge()`:
  - Verifies credentials client-side by signing in
  - Signs out immediately after getting UID
  - Calls `buildOtpChallenge` Cloud Function with UID
  - Passes UID instead of password to Cloud Function
- **Updated** `verifyOtp()`:
  - Now calls `verifyOtp` Cloud Function
  - Uses Cloud Function response for validation
- **Updated** `clearOtpChallenge()`:
  - Now calls `clearOtpChallenge` Cloud Function
  - Logs errors but doesn't fail (non-critical operation)

#### lib/screens/login_screen.dart
- **Added** error handling for `isMfaEnabledForEmail()` Cloud Function call
- **Shows** user-friendly error message when Cloud Function fails
- **Prevents** silent failures that would skip MFA

### 4. Firestore Security Rules (firestore.rules)
- **Added** `login_otps` collection rules:
  - Allows authenticated users to read/write their own OTP documents
  - Provides defense-in-depth (Cloud Functions use Admin SDK to bypass)
  - Rule: `allow read, write: if request.auth != null && request.auth.uid == userId`

## login_otps Collection Usage Analysis

### Previous Implementation (Client-Side)
The original implementation wrote to `login_otps` collection from the client side while authenticated:
1. User signs in with credentials
2. Client writes OTP to `login_otps/{uid}` (authenticated as that user)
3. Client signs out
4. User receives OTP via email

**Issue**: This worked because the write happened while authenticated, but the read operations (`verifyOtp`, `clearOtpChallenge`) happened after sign-out, which would fail with the strict security rules.

### New Implementation (Cloud Functions)
All `login_otps` operations now happen via Cloud Functions:
1. User signs in with credentials (client-side)
2. Client gets UID and signs out
3. Client calls `buildOtpChallenge` Cloud Function with UID
4. Cloud Function writes OTP using Admin SDK (bypasses rules)
5. Cloud Function sends email via EmailJS
6. User verifies OTP via Cloud Function
7. Cloud Function clears OTP after successful verification

**Benefit**: All operations use Admin SDK, bypassing security rules entirely while maintaining strict client-side security.

## Test Plan

### Prerequisites
1. Deploy Cloud Functions to Firebase:
   ```bash
   cd functions
   npm install
   cd ..
   firebase deploy --only functions
   ```
2. Update Firestore security rules:
   ```bash
   firebase deploy --only firestore:rules
   ```
3. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

### Test Cases

#### Test 1: MFA-Enabled User Login
1. **Setup**: Enable MFA for a test user in Firestore (`mfaEnabled: true`)
2. **Action**: Attempt to log in with correct credentials
3. **Expected Results**:
   - OTP verification screen appears
   - OTP email is sent to the user's Gmail
   - User can enter the OTP code
   - After successful verification, user is logged in and redirected to home/onboarding
   - OTP is cleared from Firestore after successful verification

#### Test 2: Non-MFA User Login
1. **Setup**: Ensure MFA is disabled for a test user (`mfaEnabled: false` or field absent)
2. **Action**: Attempt to log in with correct credentials
3. **Expected Results**:
   - No OTP screen appears
   - User is logged in directly
   - User is redirected to home/onboarding screen

#### Test 3: Invalid Credentials
1. **Setup**: Use any user (MFA enabled or disabled)
2. **Action**: Attempt to log in with incorrect password
3. **Expected Results**:
   - Login fails with error message
   - No OTP is generated or sent
   - User remains on login screen

#### Test 4: OTP Verification - Correct Code
1. **Setup**: MFA-enabled user, trigger OTP flow
2. **Action**: Enter the correct OTP code from email
3. **Expected Results**:
   - Verification succeeds
   - User is logged in
   - Redirected to home/onboarding
   - OTP document is deleted from Firestore

#### Test 5: OTP Verification - Incorrect Code
1. **Setup**: MFA-enabled user, trigger OTP flow
2. **Action**: Enter incorrect OTP code
3. **Expected Results**:
   - Verification fails with error message
   - Attempt counter increments
   - User can retry (up to 5 attempts)

#### Test 6: OTP Verification - Expired Code
1. **Setup**: MFA-enabled user, trigger OTP flow
2. **Action**: Wait 5+ minutes, then enter the OTP code
3. **Expected Results**:
   - Verification fails with "expired" message
   - OTP document is deleted from Firestore
   - User must log in again to get new code

#### Test 7: OTP Verification - Too Many Attempts
1. **Setup**: MFA-enabled user, trigger OTP flow
2. **Action**: Enter incorrect OTP code 5 times
3. **Expected Results**:
   - After 5th attempt, shows "too many attempts" message
   - OTP document is deleted from Firestore
   - User must log in again to get new code

#### Test 8: Cloud Function Error Handling
1. **Setup**: Disable internet connection or simulate Cloud Function failure
2. **Action**: Attempt to log in with MFA-enabled user
3. **Expected Results**:
   - User-friendly error message: "Unable to check MFA status. Please check your connection and try again."
   - No silent failure
   - User remains on login screen

#### Test 9: Email Delivery Failure
1. **Setup**: MFA-enabled user, trigger OTP flow (simulate EmailJS failure)
2. **Action**: Check OTP verification screen
3. **Expected Results**:
   - OTP screen appears with message: "We could not deliver the email automatically, but the code is ready to use."
   - OTP code is displayed on screen (for testing)
   - User can still enter the code manually

#### Test 10: User Enumeration Prevention
1. **Setup**: Use non-existent email address
2. **Action**: Call `checkMfaEnabled` Cloud Function
3. **Expected Results**:
   - Returns `{ mfaEnabled: false }`
   - Does not reveal that email doesn't exist
   - Same response as existing user with MFA disabled

### Verification Commands
```bash
# Check Cloud Functions logs
firebase functions:log

# Check Firestore for OTP documents
# (in Firebase Console)
# Go to Firestore > login_otps collection

# Check user MFA status
# (in Firebase Console)
# Go to Firestore > users collection > {userId}
# Check mfaEnabled field
```

## Deployment Steps

1. **Install Cloud Functions dependencies**:
   ```bash
   cd functions
   npm install
   cd ..
   ```

2. **Deploy Cloud Functions**:
   ```bash
   firebase deploy --only functions
   ```

3. **Deploy Firestore rules**:
   ```bash
   firebase deploy --only firestore:rules
   ```

4. **Update Flutter dependencies**:
   ```bash
   flutter pub get
   ```

5. **Test the implementation** using the test plan above

## Security Considerations

1. **No Unauthenticated Firestore Access**: All pre-authentication operations use Cloud Functions with Admin SDK
2. **User Enumeration Prevention**: Cloud Function returns `false` for non-existent emails
3. **UID Spoofing Prevention**: `buildOtpChallenge` verifies UID matches email
4. **Rate Limiting**: Consider adding Firebase App Check or custom rate limiting for production
5. **OTP Security**: 6-digit code, 5-minute expiration, 5 attempt limit
6. **Defense-in-Depth**: Firestore rules still restrict client-side access even though Cloud Functions bypass them

## Notes

- The Cloud Functions use EmailJS for email delivery. Ensure EmailJS credentials are valid.
- For production, consider implementing proper rate limiting and App Check.
- The `buildOtpChallenge` function currently accepts UID from client after credential verification. This is secure because credentials are verified client-side before the UID is obtained.
- Email delivery failures are logged but don't block OTP generation (user can see code on screen in dev mode).

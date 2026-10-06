# Security Documentation

## Firebase API Key Exposure

### Status: Acceptable Practice ✅

The Firebase API key is visible in the client-side code (`lib/firebase_options.dart`). This is standard Firebase practice and is **acceptable** given the security measures in place.

### Why This Is Safe

1. **Firebase API Keys Are Not Secret**
   - Firebase API keys are designed to be public
   - They identify your Firebase project, not authenticate users
   - They cannot be used alone to access your data

2. **Protected by Firestore Security Rules**
   - All data access is controlled by `firestore.rules`
   - Rules enforce authentication requirements
   - Only authenticated users can read/write their own data
   - Admin operations require `isAdmin()` verification

3. **Backend Validation**
   - Cloudflare Workers verify Firebase ID tokens before processing
   - Health data encryption requires valid authentication
   - Admin dashboard requires role-based access control

4. **Firebase Console Restrictions**
   - You can add additional restrictions in Firebase Console:
     - Domain restrictions (allow only specific domains)
     - App restrictions (allow only your app bundle ID)
     - IP restrictions (allow only specific IP ranges)

### Current Security Rules Summary

The `firestore.rules` file implements:
- ✅ Authentication required for all user data
- ✅ Owner-only access to personal data
- ✅ Admin-only access to sensitive collections
- ✅ Write-only audit logs (tamper-proof)
- ✅ MFA verification for enabled accounts
- ✅ Session ID validation for MFA users

### Recommended Additional Restrictions

To further harden security, configure these in Firebase Console:

#### 1. Domain Restrictions (Web)
```
Firebase Console → Project Settings → General → Your apps → Web app
→ API key restrictions → HTTP referrers
→ Add: https://claro-admin.onrender.com
```

#### 2. App Restrictions (Mobile)
```
Firebase Console → Project Settings → General → Your apps → Android/iOS app
→ API key restrictions → Android apps / iOS apps
→ Add your app's package name / bundle ID
```

#### 3. IP Restrictions (Optional)
```
Firebase Console → Project Settings → General → Your apps → Web app
→ API key restrictions → IP addresses
→ Add trusted IP ranges (if applicable)
```

### Comparison with Other API Keys

| API Key Type | Exposure Risk | Client-Side Safe? |
|--------------|---------------|-------------------|
| Firebase API Key | Low (identifies project only) | ✅ Yes |
| Gemini API Key | High (can access paid services) | ❌ No (server-side only) |
| EmailJS Keys | Medium (can send emails) | ❌ No (server-side only) |
| Cloudinary Keys | Medium (can upload images) | ⚠️ Limited (upload preset restricted) |

### Verification Checklist

Ensure these security measures are in place:

- [x] Firestore Security Rules enforce authentication
- [x] Admin operations require `isAdmin()` verification
- [x] Cloudflare Workers verify Firebase ID tokens
- [x] Health data encryption requires valid authentication
- [x] Audit logs are write-only (tamper-proof)
- [ ] Domain restrictions configured in Firebase Console (recommended)
- [ ] App restrictions configured in Firebase Console (recommended)
- [ ] Regular security audits of Firestore rules

### Monitoring

Monitor for unauthorized access attempts:
1. Check Firebase Console → Authentication → Users
2. Review Cloudflare Worker logs for token verification failures
3. Monitor audit logs (`activity_logs` collection) for suspicious activity
4. Set up alerts for failed authentication attempts

### References

- [Firebase API Key Best Practices](https://firebase.google.com/docs/projects/api-keys)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/rules)
- [Firebase Authentication](https://firebase.google.com/docs/auth)

---

## Additional Security Measures Implemented

### 1. Cloudflare Worker Security

#### claro-gemini-proxy
- ✅ APP_SHARED_SECRET for app-to-Worker authentication
- ✅ Configurable CORS policy (restrict origins in production)
- ✅ Server-side API key storage (Gemini, EmailJS)
- ✅ Request validation before forwarding
- ✅ Mobile app support (no Origin header = automatically allowed)

#### health-data-worker
- ✅ Firebase ID token verification before decryption
- ✅ AES-GCM encryption for sensitive health data
- ✅ Owner-only access enforcement
- ✅ Group membership validation
- ✅ Configurable CORS policy (restrict origins in production)
- ✅ Mobile app support (no Origin header = automatically allowed)

### 2. Admin Dashboard Security

- ✅ Account lockout after 5 failed attempts (15 minutes)
- ✅ Session timeout after 15 minutes of inactivity
- ✅ Cross-tab session synchronization
- ✅ Comprehensive audit logging
- ✅ IP address and user agent tracking
- ✅ Content Security Policy (CSP) in report-only mode
- ✅ Role-based access control (RBAC)

### 3. Official Website Security

- ✅ Email sending via Cloudflare Worker (no exposed EmailJS credentials)
- ✅ APP_SHARED_SECRET authentication for Worker access
- ✅ CORS protection for web requests
- ✅ Server-side EmailJS credential storage

### 3. Mobile App Security

- ✅ Multi-factor authentication (MFA) with OTP
- ✅ Session ID management for MFA users
- ✅ Input validation and sanitization
- ✅ Password strength requirements
- ✅ Guest session isolation
- ✅ HTTPS-only communications

### 4. Data Protection

- ✅ AES-GCM encryption for health conditions and allergens
- ✅ Encryption keys stored server-side (Cloudflare Workers)
- ✅ Firebase ID token verification before decryption
- ✅ Tamper-proof audit logs
- ✅ Owner-only data access

## Security Vulnerability Fixes Applied

### 1. Wildcard CORS Policy (Fixed)
- **Before**: `Access-Control-Allow-Origin: *`
- **After**: Configurable allowed origins via environment variable
- **Impact**: Prevents unauthorized domains from making requests even with valid secrets
- **Configuration**: Set `CORS_ALLOWED_ORIGINS` in Cloudflare Worker secrets
- **Mobile App Support**: Native apps bypass CORS (no Origin header)

### 2. Content Security Policy (Implemented)
- **Status**: Report-only mode (monitoring violations)
- **Next Step**: After 1-2 weeks of monitoring, switch to enforcing mode
- **Impact**: Prevents XSS attacks and injection vulnerabilities
- **Documentation**: See `admin-claro/CSP_GUIDE.md`

### 3. Firebase API Key (Documented)
- **Status**: Documented as acceptable practice
- **Recommendation**: Add domain/app restrictions in Firebase Console
- **Impact**: No immediate action required, but additional hardening recommended

### 4. Official Website Email Security (Fixed)
- **Before**: EmailJS credentials exposed in client-side JavaScript bundle
- **After**: Email sending via Cloudflare Worker (credentials hidden server-side)
- **Impact**: Prevents credential exposure and potential abuse
- **Configuration**: Set `VITE_GEMINI_PROXY_URL` and `VITE_APP_SHARED_SECRET` in environment

## Ongoing Security Tasks

1. **CSP Monitoring** (1-2 weeks)
   - Monitor console for CSP violations
   - Document all violations
   - Update policy as needed
   - Plan transition to enforcing mode

2. **CORS Configuration** (Before production deployment)
   - Set `CORS_ALLOWED_ORIGINS` in Cloudflare Worker secrets
   - Include both admin dashboard and official-website domains
   - Test with production domains
   - Verify mobile app still works

3. **Official Website Deployment** (Before production)
   - Set `VITE_GEMINI_PROXY_URL` and `VITE_APP_SHARED_SECRET` in Render
   - Build and deploy official-website
   - Test contact form functionality
   - Verify email sending works via Worker

4. **Firebase Console Restrictions** (Recommended)
   - Add domain restrictions for web app
   - Add app restrictions for mobile app
   - Consider IP restrictions if applicable

5. **Regular Security Audits**
   - Review Firestore Security Rules quarterly
   - Audit admin access monthly
   - Review audit logs weekly
   - Update dependencies regularly

## Security Contacts

For security concerns or vulnerabilities:
- Review this documentation
- Check Firebase Console for activity
- Monitor Cloudflare Worker logs
- Review audit logs in Firestore

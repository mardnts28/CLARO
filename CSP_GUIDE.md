# Content Security Policy (CSP) Implementation Guide

## Overview

The admin dashboard now implements Content Security Policy (CSP) to protect against Cross-Site Scripting (XSS) attacks and other injection vulnerabilities.

## Current Status: Report-Only Mode

The CSP is currently in **Report-Only mode**, which means:
- ✅ Violations are logged to the browser console
- ✅ No actual blocking occurs
- ✅ Safe to use in production immediately
- ⚠️ Does not provide active protection yet

## Current CSP Policy

```html
<meta http-equiv="Content-Security-Policy-Report-Only" content="
  default-src 'self';
  script-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.gstatic.com https://firebase.googleapis.com;
  style-src 'self' 'unsafe-inline' https://fonts.googleapis.com;
  img-src 'self' data: blob: https://res.cloudinary.com https://firebasestorage.googleapis.com;
  font-src 'self' https://fonts.gstatic.com https://fonts.googleapis.com;
  connect-src 'self' https://*.firebaseio.com https://*.googleapis.com https://api.cloudinary.com https://api.emailjs.com;
  frame-src 'self' https://firebase.googleapis.com;
  object-src 'none';
  base-uri 'self';
  form-action 'self';
  frame-ancestors 'none';
  report-uri /csp-violation-report-endpoint
">
```

## Policy Breakdown

| Directive | Purpose | Allowed Sources |
|-----------|---------|-----------------|
| `default-src` | Default fallback for all directives | Same origin only |
| `script-src` | Controls JavaScript execution | Same origin, inline scripts, eval, Firebase CDN |
| `style-src` | Controls CSS stylesheets | Same origin, inline styles, Google Fonts |
| `img-src` | Controls image loading | Same origin, data URLs, Cloudinary, Firebase Storage |
| `font-src` | Controls font loading | Same origin, Google Fonts |
| `connect-src` | Controls network requests | Same origin, Firebase, Cloudinary, EmailJS |
| `frame-src` | Controls iframe embedding | Same origin, Firebase |
| `object-src` | Controls plugins (Flash, etc.) | None (blocks all plugins) |
| `base-uri` | Controls `<base>` tag | Same origin |
| `form-action` | Controls form submissions | Same origin |
| `frame-ancestors` | Controls page embedding | None (prevents clickjacking) |

## Monitoring Violations

### 1. Browser Console

Check the browser console for CSP violation reports:
- Open Developer Tools (F12)
- Go to Console tab
- Look for "CSP Violation Detected" warnings

### 2. Example Violation Report

```
CSP Violation Detected: {
  violatedDirective: "script-src",
  effectiveDirective: "script-src-elem",
  documentURI: "https://admin.claro-app.com/dashboard",
  blockedURI: "https://untrusted-cdn.com/script.js",
  originalPolicy: "...",
  disposition: "report"
}
```

### 3. Violation Handler

The app includes a violation handler in `src/utils/CSPViolationHandler.jsx` that:
- Logs violations to the console
- Can be extended to send reports to a logging service

## Moving to Enforcing Mode

### Phase 1: Monitor (Current) - 1-2 Weeks
- ✅ Keep report-only mode active
- ✅ Monitor console for violations at https://claro-admin.onrender.com
- ✅ Document all violations
- ✅ Identify resources that need whitelisting

### Phase 2: Whitelist Resources
- Add any missing domains to the CSP policy
- Move inline scripts to external files if possible
- Remove 'unsafe-inline' and 'unsafe-eval' where feasible

### Phase 3: Test in Staging
- Change to enforcing mode in staging environment
- Test all features thoroughly
- Fix any blocking issues

### Phase 4: Production Enforcing
- Change to enforcing mode in production
- Monitor for issues
- Have rollback plan ready

## How to Enable Enforcing Mode

### Step 1: Update index.html

Change:
```html
<meta http-equiv="Content-Security-Policy-Report-Only" content="...">
```

To:
```html
<meta http-equiv="Content-Security-Policy" content="...">
```

### Step 2: Remove Report Endpoint (Optional)

Remove the `report-uri` directive if you don't have a reporting endpoint:
```html
<meta http-equiv="Content-Security-Policy" content="
  ...
  <!-- report-uri /csp-violation-report-endpoint -->
">
```

### Step 3: Tighten Policy (Optional)

Gradually remove 'unsafe-inline' and 'unsafe-eval':
```html
<script-src 'self' https://www.gstatic.com https://firebase.googleapis.com>
```

## Common Issues and Solutions

### Issue: Firebase SDK Not Loading
**Symptom**: Console shows CSP violation for Firebase scripts
**Solution**: Ensure `https://www.gstatic.com` and `https://firebase.googleapis.com` are in `script-src`

### Issue: Images Not Loading
**Symptom**: Images from Cloudinary don't appear
**Solution**: Add `https://res.cloudinary.com` to `img-src`

### Issue: Fonts Not Loading
**Symptom**: Google Fonts don't appear
**Solution**: Ensure `https://fonts.googleapis.com` and `https://fonts.gstatic.com` are in `font-src`

### Issue: Network Requests Blocked
**Symptom**: API calls to Firebase fail
**Solution**: Add Firebase domains to `connect-src`:
- `https://*.firebaseio.com`
- `https://*.googleapis.com`

## Testing CSP

### Manual Testing
1. Open browser DevTools
2. Go to Console tab
3. Navigate through the app
4. Check for CSP violations

### Automated Testing
Use tools like:
- [CSP Evaluator](https://csp-evaluator.withgoogle.com/)
- [Lighthouse](https://developers.google.com/web/tools/lighthouse)
- Browser extensions for CSP testing

## Rollback Plan

If enforcing mode causes issues:
1. Immediately revert to report-only mode
2. Investigate the blocking issues
3. Update the CSP policy
4. Test again in staging
5. Retry enforcing mode

## Additional Resources

- [MDN CSP Documentation](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)
- [CSP Level 3 Specification](https://www.w3.org/TR/CSP3/)
- [Google CSP Best Practices](https://web.dev/csp/)

## Support

If you encounter issues:
1. Check browser console for violation details
2. Review this guide for common solutions
3. Document the violation details
4. Update the CSP policy accordingly

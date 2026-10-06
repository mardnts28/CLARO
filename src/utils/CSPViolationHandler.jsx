/**
 * CSP Violation Handler
 * 
 * This component handles Content Security Policy violation reports.
 * In report-only mode, violations are logged but not blocked.
 * In enforcing mode, violations would be blocked entirely.
 * 
 * Usage:
 * 1. Add this component to your main.jsx
 * 2. Check browser console for violation reports
 * 3. Review logs to identify resources that need whitelisting
 */

export const logCSPViolation = (report) => {
  console.warn('CSP Violation Detected:', {
    violatedDirective: report.violatedDirective,
    effectiveDirective: report.effectiveDirective,
    documentURI: report.documentURI,
    blockedURI: report.blockedURI,
    originalPolicy: report.originalPolicy,
    disposition: report.disposition,
  });

  // Send to your logging service (optional)
  // await logToService('CSP_VIOLATION', report);
};

// Simple CSP report listener for development
export const setupCSPMonitoring = () => {
  if (typeof window !== 'undefined' && window.addEventListener) {
    window.addEventListener('securitypolicyviolation', (event) => {
      logCSPViolation({
        violatedDirective: event.violatedDirective,
        effectiveDirective: event.effectiveDirective,
        documentURI: event.documentURI,
        blockedURI: event.blockedURI,
        originalPolicy: event.originalPolicy,
        disposition: event.disposition,
      });
    });
  }
};

export default { logCSPViolation, setupCSPMonitoring };

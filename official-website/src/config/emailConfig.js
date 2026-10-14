// Email configuration for the Contact Us form.
//
// This project now uses the Cloudflare Worker (claro-gemini-proxy) to send emails
// securely, hiding EmailJS credentials server-side instead of exposing them in
// the client-side JavaScript bundle.
//
// The Worker handles:
//   - EmailJS service ID, template ID, and private key (server-side only)
//   - Authentication via APP_SHARED_SECRET
//   - Rate limiting and abuse prevention
//
// Set these in a local .env file (see .env.example) so real values are never
// committed to the repo:
//   VITE_GEMINI_PROXY_URL=https://claro-gemini-proxy.claro-app.workers.dev
//   VITE_APP_SHARED_SECRET=your_shared_secret
//
// The Worker's /email endpoint expects:
//   template_params: {
//     to_email: recipient email,
//     passcode: (not used for contact form, but required by template),
//     time: (not used for contact form, but required by template),
//     from_name: sender name,
//     from_email: sender email,
//     message: message content
//   }
export const GEMINI_PROXY_URL = import.meta.env.VITE_GEMINI_PROXY_URL || 'https://claro-gemini-proxy.claro-app.workers.dev';
export const APP_SHARED_SECRET = import.meta.env.VITE_APP_SHARED_SECRET || 'YOUR_APP_SHARED_SECRET';

// Fixed recipient for all Contact Us submissions.
export const CONTACT_RECIPIENT_EMAIL = 'mrasalucop01@tip.edu.ph';

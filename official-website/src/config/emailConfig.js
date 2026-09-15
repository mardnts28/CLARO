// EmailJS configuration for the Contact Us form.
//
// This project sends the contact form using an EXISTING EmailJS service and
// template (per the "Use existing templates" requirement), so no template is
// created here — you just need to plug in your account's IDs below.
//
// Where to find these values (https://dashboard.emailjs.com):
//   1. VITE_EMAILJS_SERVICE_ID  -> Email Services tab, the Service ID of the
//      connected email service (e.g. Gmail) you want the message sent from.
//   2. VITE_EMAILJS_TEMPLATE_ID -> Email Templates tab, the ID of the existing
//      template you want to reuse for the Contact Us message.
//   3. VITE_EMAILJS_PUBLIC_KEY  -> Account > General, your Public Key.
//
// Set these in a local .env file (see .env.example) so real keys are never
// committed to the repo:
//   VITE_EMAILJS_SERVICE_ID=your_service_id
//   VITE_EMAILJS_TEMPLATE_ID=your_template_id
//   VITE_EMAILJS_PUBLIC_KEY=your_public_key
//
// IMPORTANT: Your existing EmailJS template must contain variables that match
// the ones sent from the Contact Us form (see ContactUs.jsx):
//   {{from_name}}, {{from_email}}, {{message}}, {{to_email}}
// If your template uses different variable names, either rename the fields
// sent in ContactUs.jsx's templateParams, or update the template in your
// EmailJS dashboard to match.
export const EMAILJS_SERVICE_ID = import.meta.env.VITE_EMAILJS_SERVICE_ID || 'YOUR_SERVICE_ID';
export const EMAILJS_TEMPLATE_ID = import.meta.env.VITE_EMAILJS_TEMPLATE_ID || 'YOUR_TEMPLATE_ID';
export const EMAILJS_PUBLIC_KEY = import.meta.env.VITE_EMAILJS_PUBLIC_KEY || 'YOUR_PUBLIC_KEY';

// Fixed recipient for all Contact Us submissions.
export const CONTACT_RECIPIENT_EMAIL = 'mrasalucop01@tip.edu.ph';

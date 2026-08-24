import { Clock, Shield } from 'lucide-react';
import './Pages.css';

export default function PrivacyPolicy() {
  return (
    <div className="privacy-page page-section">
      <div className="doc-container">
        {/* Page Header */}
        <div className="page-header" style={{ marginBottom: '2rem' }}>
          <h1 className="page-title">Privacy Policy</h1>
          <p className="page-subtitle">
            This Privacy Policy explains how CLARO collects, uses, stores, protects, and manages personal information in accordance with the Data Privacy Act of 2012 (Republic Act No. 10173) and its applicable principles and regulations.

By using CLARO, you acknowledge that you have read and understood this Privacy Policy.
          </p>
        </div>

        {/* Document Card */}
        <div className="doc-card">
          <div className="doc-meta">
            <Clock size={16} />
            <span>Last Updated: August 10, 2026</span>
            <span style={{ margin: '0 0.5rem' }}>•</span>
            <Shield size={16} />
            <span>Version 1.0</span>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">1. Information We Collect</h2>
            <p className="doc-section-text">
              CLARO follows the data minimization principle, meaning that we only collect information reasonably necessary to provide the application's intended functionality.
            </p>
            <h3 className="doc-section-title" style={{ fontSize: '1.1rem', marginTop: '1.5rem' }}>1.1 CLARO Mobile Application Users</h3>
            <p className="doc-section-text">
              When you create or access an account, CLARO may collect the following information:
            </p>
            <ul className="doc-section-text" style={{ marginLeft: '1.5rem', marginTop: '0.5rem' }}>
              <li>Display name</li>
              <li>Authentication information associated with your account</li>
              <li>Health-related conditions selected by you, if applicable</li>
              <li>Food allergies identified by you, if applicable</li>
            </ul>
            <p className="doc-section-text" style={{ marginTop: '1rem' }}>
              Your display name is used as an identifier and may be displayed within your user dashboard.
            </p>
            <p className="doc-section-text">
              Health conditions and food allergies are collected solely to provide personalized health assessments, warnings, and recommendations when you use the application's product scanning and nutritional analysis features.
            </p>
            <p className="doc-section-text">
              CLARO does not intentionally collect unnecessary personal information such as:
            </p>
            <ul className="doc-section-text" style={{ marginLeft: '1.5rem', marginTop: '0.5rem' }}>
              <li>Government-issued identification numbers</li>
              <li>Physical address</li>
              <li>Contact numbers</li>
              <li>Financial or payment information</li>
              <li>Passwords in plaintext</li>
            </ul>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">2. Authentication</h2>
            <p className="doc-section-text">
              CLARO supports multiple authentication methods, including:
            </p>
            <ul className="doc-section-text" style={{ marginLeft: '1.5rem', marginTop: '0.5rem' }}>
              <li>Standard email and password authentication</li>
              <li>Google Sign-In through Google OAuth 2.0</li>
            </ul>
            <p className="doc-section-text" style={{ marginTop: '1rem' }}>
              Authentication is handled through Firebase Authentication.
            </p>
            <p className="doc-section-text">
              For Google Sign-In, authentication is handled by Google and CLARO receives an authenticated credential/token necessary to establish the user's authenticated session. CLARO does not receive or store the user's Google password.
            </p>
            <p className="doc-section-text">
              For standard authentication, credentials are securely managed by Firebase Authentication. Passwords are not stored as plaintext within the CLARO's application database.
            </p>
            <p className="doc-section-text">
              Multi-factor authentication may be available as an optional security feature.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">3. How We Use Your Information</h2>
            <p className="doc-section-text">
              The information collected through CLARO is used only for legitimate and necessary purposes related to the application's functionality.
            </p>
            <p className="doc-section-text">
              Your information may be used to:
            </p>
            <ul className="doc-section-text" style={{ marginLeft: '1.5rem', marginTop: '0.5rem' }}>
              <li>Identify your account within the application</li>
              <li>Display your profile information</li>
              <li>Store and manage your health profile</li>
              <li>Generate personalized health advisories</li>
              <li>Display warnings related to selected health conditions</li>
              <li>Display allergen warnings based on the allergies you provide</li>
              <li>Provide recommendations based on your selected health profile</li>
              <li>Improve the functionality and reliability of the application</li>
              <li>Maintain application security and authentication</li>
            </ul>
            <p className="doc-section-text" style={{ marginTop: '1rem' }}>
              We do not use your health profile information for advertising or unrelated commercial purposes.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">4. Health Information</h2>
            <p className="doc-section-text">
              CLARO allows users to voluntarily provide information about selected health conditions and food allergies.
            </p>
            <p className="doc-section-text">
              This information is used specifically to personalize product-related advisories and warnings.
            </p>
            <p className="doc-section-text">
              For example, information provided in your health profile may be used to display warnings or recommendations related to conditions such as:
            </p>
            <ul className="doc-section-text" style={{ marginLeft: '1.5rem', marginTop: '0.5rem' }}>
              <li>Diabetes</li>
              <li>Hypertension</li>
              <li>Heart or cardiovascular conditions</li>
              <li>Kidney-related dietary considerations</li>
              <li>Food allergies</li>
            </ul>
            <p className="doc-section-text" style={{ marginTop: '1rem' }}>
              You control the information included in your health profile and may update it when necessary.
            </p>
            <p className="doc-section-text">
              Because health-related information may be sensitive, CLARO applies access controls and security measures intended to prevent unauthorized access.
            </p>
            <p className="doc-section-text">
              In addition to standard infrastructure protections, your health conditions and food allergies are individually encrypted before being stored, providing an added layer of protection for this specific data.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">5. Storage and Security of User Data</h2>
            <p className="doc-section-text">
              User information is stored using cloud-based services, including Firebase Authentication and Firebase Firestore.
            </p>
            <p className="doc-section-text">
              User health profile information stored in Firestore is associated with a unique user identifier. Firebase Security Rules are used to restrict access so that an authenticated user can access and modify their own health profile information.
            </p>
            <p className="doc-section-text">
              CLARO applies technical security measures including:
            </p>
            <ul className="doc-section-text" style={{ marginLeft: '1.5rem', marginTop: '0.5rem' }}>
              <li>Authentication through Firebase Authentication</li>
              <li>Firebase Security Rules</li>
              <li>Access restrictions for user-owned data</li>
              <li>Encryption of data in transit through HTTPS/TLS</li>
              <li>Encryption of data at rest provided by the underlying Firebase infrastructure</li>
              <li>Additional field-level encryption applied specifically to health conditions and food allergies stored in your profile</li>
              <li>Controlled administrator access</li>
              <li>Security and audit logging for administrative activities</li>
            </ul>
            <p className="doc-section-text" style={{ marginTop: '1rem' }}>
              While reasonable measures are implemented to protect personal information, no electronic storage or transmission system can be guaranteed to be completely secure.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">6. Third-Party Services</h2>
            <p className="doc-section-text">
              CLARO relies on certain third-party services to provide core functionality.
            </p>
            <p className="doc-section-text">
              These may include:
            </p>
            <h3 className="doc-section-title" style={{ fontSize: '1.1rem', marginTop: '1.5rem' }}>Firebase</h3>
            <p className="doc-section-text">
              Firebase is used for authentication and cloud data storage. Authentication credentials are managed by Firebase Authentication, while user profile information is stored in Firestore.
            </p>
            <h3 className="doc-section-title" style={{ fontSize: '1.1rem', marginTop: '1.5rem' }}>Google</h3>
            <p className="doc-section-text">
              Google OAuth 2.0 may be used when a user chooses Google Sign-In. Google is responsible for authenticating the user's Google account.
            </p>
            <h3 className="doc-section-title" style={{ fontSize: '1.1rem', marginTop: '1.5rem' }}>Nutritional and Regulatory Reference Sources</h3>
            <p className="doc-section-text">
              CLARO may retrieve or reference information from publicly available nutritional and regulatory sources, including information associated with the Philippine Food and Drug Administration (FDA) and the World Health Organization (WHO).
            </p>
            <p className="doc-section-text">
              Regulatory reference information, such as product CPR numbers and validity dates, is treated as reference data and is not modified by users.
            </p>
            <h3 className="doc-section-title" style={{ fontSize: '1.1rem', marginTop: '1.5rem' }}>AI-Assisted Health Advisory Processing</h3>
            <p className="doc-section-text">
              CLARO may use an AI-based service, such as Gemini Flash 2.5, to assist in generating explanations for health advisories.
            </p>
            <p className="doc-section-text">
              Where applicable, only information necessary to generate the requested advisory should be processed. If the AI service is temporarily unavailable, CLARO may use a rule-based fallback mechanism to generate the advisory.
            </p>
            <p className="doc-section-text" style={{ marginTop: '1rem', fontStyle: 'italic' }}>
              Implementation note: If your actual implementation sends health-profile information or product information to Gemini, this section should be kept and the exact data transmitted should be documented. If the AI processing is entirely local and no user data leaves your controlled infrastructure, this section should be revised accordingly.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">7. Product and Nutritional Information</h2>
            <p className="doc-section-text">
              CLARO may display information about food products, including:
            </p>
            <ul className="doc-section-text" style={{ marginLeft: '1.5rem', marginTop: '0.5rem' }}>
              <li>Product name</li>
              <li>Brand</li>
              <li>Product image</li>
              <li>Serving size</li>
              <li>Nutritional information</li>
              <li>CPR/registration number</li>
              <li>Registration validity information</li>
              <li>Nutri-Score</li>
              <li>NOVA classification</li>
              <li>Health advisories</li>
              <li>Allergen information</li>
            </ul>
            <p className="doc-section-text" style={{ marginTop: '1rem' }}>
              Information from external sources is treated as reference information. CLARO does not guarantee that third-party nutritional, regulatory, or product information will always be complete, current, or error-free.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">8. Unrecognized Product Reports</h2>
            <p className="doc-section-text">
              Users may report products that are not recognized by the application.
            </p>
            <p className="doc-section-text">
              A submitted report may contain information such as:
            </p>
            <ul className="doc-section-text" style={{ marginLeft: '1.5rem', marginTop: '0.5rem' }}>
              <li>Product image</li>
              <li>Product-related information submitted through the reporting feature</li>
              <li>Information necessary for administrators to validate the product</li>
            </ul>
            <p className="doc-section-text" style={{ marginTop: '1rem' }}>
              Submitted reports are reviewed by authorized administrators before any action is taken.
            </p>
            <p className="doc-section-text">
              This review process is intended to reduce fraudulent, inaccurate, or inappropriate submissions.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">9. Administrator Information</h2>
            <p className="doc-section-text">
              Access to the CLARO administrator dashboard is restricted to authorized administrator accounts.
            </p>
            <p className="doc-section-text">
              For administrators, CLARO collects:
            </p>
            <ul className="doc-section-text" style={{ marginLeft: '1.5rem', marginTop: '0.5rem' }}>
              <li>Email address</li>
              <li>Authentication information managed by Firebase Authentication</li>
              <li>Login date and time</li>
              <li>Logout date and time</li>
              <li>Administrative activity or actions performed within the dashboard</li>
            </ul>
            <p className="doc-section-text" style={{ marginTop: '1rem' }}>
              Administrator passwords are managed by Firebase Authentication and are not stored as plaintext within the CLARO system.
            </p>
            <p className="doc-section-text">
              Administrator activity logs are maintained for security, monitoring, and audit purposes.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">10. Survey Participant Information</h2>
            <p className="doc-section-text">
              As part of requirements gathering and system evaluation, CLARO's researchers may conduct surveys.
            </p>
            <p className="doc-section-text">
              Participation is voluntary.
            </p>
            <p className="doc-section-text">
              Survey information may include:
            </p>
            <ul className="doc-section-text" style={{ marginLeft: '1.5rem', marginTop: '0.5rem' }}>
              <li>Email address</li>
              <li>Name, if voluntarily provided</li>
              <li>Age range</li>
              <li>Sex</li>
              <li>Survey responses</li>
            </ul>
            <p className="doc-section-text" style={{ marginTop: '1rem' }}>
              Email addresses are collected primarily to help verify that responses came from actual participants.
            </p>
            <p className="doc-section-text">
              Survey information is used solely for research, analysis, evaluation, and reporting purposes.
            </p>
            <p className="doc-section-text">
              Survey information will be securely stored during the study and deleted after completion of the study in accordance with the researchers' data-retention procedures.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">11. Data Retention</h2>
            <p className="doc-section-text">
              CLARO retains personal information only for as long as reasonably necessary to provide the application's functionality, maintain security, comply with applicable requirements, or complete the research study for which the information was collected.
            </p>
            <p className="doc-section-text">
              Users may request deletion of their account and associated user information through the application's account deletion feature.
            </p>
            <p className="doc-section-text">
              Survey participant information will be deleted after completion of the study, subject to applicable research and institutional requirements.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">12. Account Deletion</h2>
            <p className="doc-section-text">
              Users may delete their CLARO account through the application's account deletion feature.
            </p>
            <p className="doc-section-text">
              When an account deletion request is successfully completed, the user's authentication account and corresponding user information stored in the CLARO system are deleted, subject to any information that may be required to be retained under applicable law or legitimate security/audit requirements.
            </p>
            <p className="doc-section-text">
              After account deletion, the user will be required to create or use another account to access CLARO's authenticated features.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">13. Your Privacy Rights</h2>
            <p className="doc-section-text">
              Under the Data Privacy Act of 2012 (R.A. 10173), applicable data subjects may have rights concerning their personal information, including the right to:
            </p>
            <ul className="doc-section-text" style={{ marginLeft: '1.5rem', marginTop: '0.5rem' }}>
              <li>Be informed about the collection and processing of personal information</li>
              <li>Access personal information held about them</li>
              <li>Request correction of inaccurate or incomplete information</li>
              <li>Object to certain processing where applicable</li>
              <li>Request deletion or blocking of personal information where applicable</li>
              <li>Exercise data portability where applicable</li>
              <li>Lodge a complaint regarding the processing of personal information</li>
            </ul>
            <p className="doc-section-text" style={{ marginTop: '1rem' }}>
              Requests concerning personal information may be directed to:
            </p>
            <p className="doc-section-text">
              <strong>Privacy Contact:</strong> [Insert Contact Information]<br />
              <strong>Email:</strong> [Insert Email Address]
            </p>
            <p className="doc-section-text" style={{ marginTop: '1rem' }}>
              Requests will be handled in accordance with applicable privacy laws and verification procedures.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">14. Children's Privacy</h2>
            <p className="doc-section-text">
              CLARO is not specifically designed to collect personal information from children.
            </p>
            <p className="doc-section-text">
              Users should not provide information belonging to another person, including a child, without appropriate authorization or consent.
            </p>
            <p className="doc-section-text">
              If you believe that personal information has been collected improperly, please contact us using the information provided in this Privacy Policy.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">15. Changes to This Privacy Policy</h2>
            <p className="doc-section-text">
              We may update this Privacy Policy when necessary to reflect changes in the application's functionality, data practices, security measures, or applicable legal requirements.
            </p>
            <p className="doc-section-text">
              When changes are made, the updated Last Updated date will be displayed at the top of this page.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

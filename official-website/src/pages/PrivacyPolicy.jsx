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
            Document template for CLARO user privacy and data protection guidelines.
          </p>
        </div>

        {/* Document Card */}
        <div className="doc-card">
          <div className="doc-meta">
            <Clock size={16} />
            <span>Last Updated: [Placeholder Date]</span>
            <span style={{ margin: '0 0.5rem' }}>•</span>
            <Shield size={16} />
            <span>Version 1.0 Template</span>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">1. Information Collection (Placeholder)</h2>
            <p className="doc-section-text">
              This section is reserved for outlining what information CLARO collects, such as food images captured for recognition, minimal user preference settings, and device telemetry data if applicable.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">2. How Information is Used (Placeholder)</h2>
            <p className="doc-section-text">
              This section will describe how collected food scan data and nutritional queries are processed strictly to deliver AI-driven nutrition guidance and improve model accuracy.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">3. Data Storage & Security (Placeholder)</h2>
            <p className="doc-section-text">
              Details regarding data storage location, encryption protocols, access controls, and retention periods will be specified here when the official policy is published.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">4. Third-Party Integrations (Placeholder)</h2>
            <p className="doc-section-text">
              Information regarding third-party services, nutrition databases, or cloud infrastructure utilized by the CLARO platform will be disclosed in this section.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">5. User Rights & Enquiries (Placeholder)</h2>
            <p className="doc-section-text">
              Instructions for users on how to request data deletion, opt out of analytics, or contact the CLARO development team regarding privacy concerns will be detailed here.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

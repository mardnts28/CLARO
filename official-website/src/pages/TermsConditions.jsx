import { Clock, FileCheck } from 'lucide-react';
import './Pages.css';

export default function TermsConditions() {
  return (
    <div className="terms-page page-section">
      <div className="doc-container">
        {/* Page Header */}
        <div className="page-header" style={{ marginBottom: '2rem' }}>
          <h1 className="page-title">Terms & Conditions</h1>
          <p className="page-subtitle">
            Terms of service and usage conditions template for the CLARO project.
          </p>
        </div>

        {/* Document Card */}
        <div className="doc-card">
          <div className="doc-meta">
            <Clock size={16} />
            <span>Last Updated: [Placeholder Date]</span>
            <span style={{ margin: '0 0.5rem' }}>•</span>
            <FileCheck size={16} />
            <span>Terms Version 1.0 Template</span>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">1. Acceptance of Terms (Placeholder)</h2>
            <p className="doc-section-text">
              This section will specify that by accessing or using the CLARO application and website, users agree to abide by these Terms & Conditions and all applicable regulations.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">2. Scope & Purpose (Placeholder)</h2>
            <p className="doc-section-text">
              Statement indicating that CLARO is developed as an academic capstone project focused on smart food recognition and nutrition guidance for informational purposes.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">3. User Conduct & Use Guidelines (Placeholder)</h2>
            <p className="doc-section-text">
              Outline of permitted and prohibited activities when using the platform, including proper use of image scanning features and respect for system limitations.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">4. Intellectual Property (Placeholder)</h2>
            <p className="doc-section-text">
              Information regarding ownership of the CLARO logo, branding assets, software source code, machine learning models, and original website design elements.
            </p>
          </div>

          <div className="doc-section">
            <h2 className="doc-section-title">5. Disclaimer of Health & Medical Advice (Placeholder)</h2>
            <p className="doc-section-text">
              Explicit disclaimer noting that nutritional data and automated food recognition results are provided for general guidance and do not replace professional medical or dietary advice.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

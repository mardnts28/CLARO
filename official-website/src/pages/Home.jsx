import { Download, Sparkles, Scan, HeartPulse, ShieldCheck, ArrowRight } from 'lucide-react';
import logoImg from '../assets/images/logoII.png';
import './Pages.css';

export default function Home() {
  const handleDownloadClick = (e) => {
    e.preventDefault();
    // Visual button only as specified by requirements
  };

  return (
    <div className="home-page">
      {/* Hero Section */}
      <section className="hero-section">
        <div className="container hero-grid">
          <div className="hero-content">
            <div className="hero-badge-wrap">
              <span className="badge">Capstone Project</span>
            </div>
            <h1 className="hero-title">
              <span className="hero-title-accent">CLARO</span>
            </h1>
            <p className="hero-subtitle">
              Smart food recognition and nutrition guidance
            </p>
            
            <div className="hero-actions">
              <button
                className="btn-primary"
                onClick={handleDownloadClick}
                title="Download non-functional placeholder"
                aria-label="Download CLARO App (Visual Template Button)"
              >
                <Download size={18} />
                <span>Download App</span>
              </button>

              <span className="badge" style={{ background: 'var(--card-bg)', border: '1px solid var(--border-color)', color: 'var(--text-secondary)' }}>
                Template Preview Mode
              </span>
            </div>

            <p className="download-tooltip-note">
              * The Download button is a visual placeholder for UI demonstration.
            </p>
          </div>

          {/* Hero Visual Mockup Card */}
          <div className="hero-visual">
            <div className="hero-mockup-card">
              <div className="mockup-header">
                <img src={logoImg} alt="CLARO Logo Preview" className="mockup-logo-img" />
                <div>
                  <h4 className="mockup-title">CLARO Assistant</h4>
                  <p style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>Placeholder UI Card</p>
                </div>
              </div>

              <div className="mockup-content-placeholder">
                <div className="skeleton-box h-40"></div>
                <div className="skeleton-box h-120"></div>
                <div className="skeleton-box h-20" style={{ width: '70%' }}></div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Feature Placeholders Section */}
      <section className="page-section">
        <div className="container">
          <div className="section-header">
            <span className="badge" style={{ marginBottom: '0.75rem' }}>System Capabilities</span>
            <h2 className="section-title">Features Overview</h2>
            <p className="section-subtitle">
              Placeholder section demonstrating feature breakdown card structures.
            </p>
          </div>

          <div className="cards-grid-3">
            <div className="card feature-card">
              <div className="feature-icon-wrapper">
                <Scan size={24} />
              </div>
              <h3 className="feature-title">Smart Food Recognition</h3>
              <p>
                Placeholder description for intelligent food image analysis and identification functionality.
              </p>
            </div>

            <div className="card feature-card">
              <div className="feature-icon-wrapper">
                <HeartPulse size={24} />
              </div>
              <h3 className="feature-title">Nutrition Guidance</h3>
              <p>
                Placeholder description for dietary insights, nutritional breakdown, and personalized recommendation metrics.
              </p>
            </div>

            <div className="card feature-card">
              <div className="feature-icon-wrapper">
                <ShieldCheck size={24} />
              </div>
              <h3 className="feature-title">Health Advisory</h3>
              <p>
                Placeholder description for health alert prompts, ingredient awareness, and nutritional safety guides.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* How CLARO Works Section */}
      <section className="page-section" style={{ backgroundColor: 'rgba(255, 255, 255, 0.4)' }}>
        <div className="container">
          <div className="section-header">
            <span className="badge" style={{ marginBottom: '0.75rem' }}>Workflow</span>
            <h2 className="section-title">How CLARO Works</h2>
            <p className="section-subtitle">
              A 3-step placeholder process layout demonstrating application flow.
            </p>
          </div>

          <div className="workflow-grid">
            <div className="card step-card">
              <span className="step-number">01</span>
              <h3>Capture or Upload</h3>
              <p>
                Placeholder step description detailing how users scan or upload food items into the system.
              </p>
            </div>

            <div className="card step-card">
              <span className="step-number">02</span>
              <h3>AI Analysis</h3>
              <p>
                Placeholder step description explaining system processing, recognition model, and data lookup.
              </p>
            </div>

            <div className="card step-card">
              <span className="step-number">03</span>
              <h3>Receive Guidance</h3>
              <p>
                Placeholder step description illustrating nutritional summaries and health guidance output.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Call to Action Section */}
      <section className="page-section">
        <div className="container">
          <div className="cta-banner">
            <Sparkles size={32} style={{ color: 'var(--primary-red)' }} />
            <h2>Experience CLARO Capstone Project</h2>
            <p className="section-subtitle">
              Placeholder CTA area for project launch, documentation links, or future store release highlights.
            </p>
            <button className="btn-primary" onClick={handleDownloadClick}>
              <span>Download Visual Template</span>
              <ArrowRight size={18} />
            </button>
          </div>
        </div>
      </section>
    </div>
  );
}

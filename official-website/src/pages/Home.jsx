import { Download, Scan, FileText, ShieldCheck, HeartPulse, GitCompare, Mic } from 'lucide-react';
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
            <h1 className="hero-title">
              <span className="hero-title-accent">CLARO</span>
            </h1>
            <p className="hero-subtitle">
              An AI-Powered Mobile Application for Health-Informed Decision-Making on FDA-Registered Filipino Canned Fish, Meat, Vegetables and Local Instant Noodle Products
            </p>
            
            <div className="hero-actions">
              <button
                className="btn-primary"
                onClick={handleDownloadClick}
                title="Install CLARO App"
                aria-label="Install CLARO App"
              >
                <Download size={18} />
                <span>Install CLARO App</span>
              </button>
            </div>
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

      {/* About CLARO Section */}
      <section className="page-section">
        <div className="container">
          <div className="cta-banner">
            <h2 className="section-title">About CLARO</h2>
            <p className="section-subtitle">
              CLARO is an AI-powered mobile app that helps grocery shoppers understand nutrition information for local canned foods. By scanning a product, users see simplified nutrition summaries, health advisories, allergen warnings, product comparisons, and accessibility features such as voice assistance to make smarter and healthier buying decisions.
            </p>
          </div>
        </div>
      </section>

      {/* Features Overview Section */}
      <section className="page-section">
        <div className="container">
          <div className="section-header">
            <h2 className="section-title">Features Overview</h2>
            <p className="section-subtitle">
              Here are the core features of CLARO:
            </p>
          </div>

          <div className="cards-grid-3">
            <div className="card feature-card">
              <div className="feature-icon-wrapper">
                <Scan size={24} />
              </div>
              <h3 className="feature-title">AI Food Recognition</h3>
              <p>
                Identifies local canned food and instant noodle products using a trained YOLOv8 image scanning model with auto-detection and capture.
              </p>
            </div>

            <div className="card feature-card">
              <div className="feature-icon-wrapper">
                <FileText size={24} />
              </div>
              <h3 className="feature-title">Nutritional Information & Food Classification</h3>
              <p>
                Presents ingredients, allergens, Nutri-Score, and NOVA classification of identified product.
              </p>
            </div>

            <div className="card feature-card">
              <div className="feature-icon-wrapper">
                <ShieldCheck size={24} />
              </div>
              <h3 className="feature-title">FDA Registration Verification</h3>
              <p>
                Checks the product’s FDA registration status through the Philippine FDA Verification Portal.
              </p>
            </div>

            <div className="card feature-card">
              <div className="feature-icon-wrapper">
                <HeartPulse size={24} />
              </div>
              <h3 className="feature-title">Health Profile & Advisory</h3>
              <p>
                Provides a health advisory based on conditions such as hypertension, diabetes, heart disease, and food allergies, using Food and Drug Association (FDA) nutrition label reading guidance, and Word Health Organization (WHO) daily nutrition intake guidance.
              </p>
            </div>

            <div className="card feature-card">
              <div className="feature-icon-wrapper">
                <GitCompare size={24} />
              </div>
              <h3 className="feature-title">Product Comparison & Ranking</h3>
              <p>
                Compares and ranks up to five products based on their suitability to the user’s health profile, recommending the best choice for your health condition.
              </p>
            </div>

            <div className="card feature-card">
              <div className="feature-icon-wrapper">
                <Mic size={24} />
              </div>
              <h3 className="feature-title">Voice Assistance</h3>
              <p>
                Offers hands-free navigation, and screen reading for accessibility through voice commands, supporting English and Tagalog Language.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* How CLARO Works Section */}
      <section className="page-section" style={{ backgroundColor: 'var(--card-bg-alt)' }}>
        <div className="container">
          <div className="section-header">
            <h2 className="section-title">How CLARO Works</h2>
          </div>

          <div className="workflow-grid">
            <div className="card step-card">
              <span className="step-number">01</span>
              <h3>Point and Capture</h3>
              <p>
                Aim the camera at a Philippine brand canned food or instant noodles. The app auto-detects the object and captures when the product is properly framed.
              </p>
            </div>

            <div className="card step-card">
              <span className="step-number">02</span>
              <h3>Receive Analysis</h3>
              <p style={{ marginBottom: '0.5rem' }}>
                once the product has been recognized, you may instantly view:
              </p>
              <ul className="step-details-list">
                <li>Product's Information and FDA Registration number and its expiry date</li>
                <li>Complete ingredients and Nutrition Facts</li>
                <li>Nutri-Score and NOVA Classification</li>
                <li>Health Advisory</li>
              </ul>
            </div>

            <div className="card step-card">
              <span className="step-number">03</span>
              <h3>Compare Products</h3>
              <p>
                scan multiple products or tap the compare button to view ranked list and recommendation
              </p>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
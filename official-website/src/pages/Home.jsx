import { useState, useEffect } from 'react';
import { Download, Scan, FileText, ShieldCheck, HeartPulse, GitCompare, Mic } from 'lucide-react';
import logoImg from '../assets/images/logoII.png';
import logoBorder from '../assets/images/logo-border.png';
import logoCan from '../assets/images/logo-can.png';
import appPreviewImg1 from '../assets/images/preview1.png';
import appPreviewImg2 from '../assets/images/preview2.png';
import heroBgImg from '../assets/images/hero-bg.jpg'; // TODO: point this at your actual hero background image
import AboutClaro from '../components/AboutClaro';
import HowClaroWorks from '../components/HowClaroWorks';
import './Pages.css';

// TODO: update this to wherever the APK is actually hosted (Firebase Hosting,
// your own server, etc). Use the arm64-v8a build — it covers the vast
// majority of modern Android phones.
   const APK_DOWNLOAD_URL = '';

export default function Home() {
  const [isAndroid, setIsAndroid] = useState(false);

  useEffect(() => {
    const userAgent = navigator.userAgent || navigator.vendor || '';
    setIsAndroid(/android/i.test(userAgent));
  }, []);

  const handleDownloadClick = (e) => {
    if (!isAndroid) {
      e.preventDefault();
      return;
    }
    window.location.href = APK_DOWNLOAD_URL;
  };

  return (
    <div className="home-page">
      {/* Hero Section */}
      <section className="hero-section" style={{ backgroundImage: `url(${heroBgImg})` }}>
        <div className="container hero-grid">
          <div className="hero-content">
            <div className="hero-logo-launch">
              <div className="logo-border-container">
                <img src={logoBorder} alt="CLARO Logo Border" className="logo-border" />
              </div>
              <div className="logo-can-container">
                <img src={logoCan} alt="CLARO Logo Can" className="logo-can" />
              </div>
            </div>
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
                disabled={!isAndroid}
                title={isAndroid ? 'Install CLARO App' : 'Available on Android devices only'}
                aria-label={isAndroid ? 'Install CLARO App' : 'Available on Android devices only'}
              >
                <Download size={18} />
                <span>{isAndroid ? 'Install CLARO App' : 'Android compatible only'}</span>
              </button>
            </div>
          </div>

          {/* Hero Visual - App Preview Image */}
          <div className="hero-visual">
            <img src={appPreviewImg1} alt="CLARO App Preview" className="app-preview-image" />
            <img src={appPreviewImg2} alt="CLARO App Preview" className="app-preview-image" />
          </div>
        </div>
      </section>

      {/* About CLARO Section */}
      <AboutClaro />

      {/* How CLARO Works Section */}
      <HowClaroWorks />

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
                Identifies local canned food and instant noodle products using a trained YOLOv8 image scanning model.
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
                Provides a health advisory based on common conditions such as hypertension, diabetes, heart disease, GERD, Chronic kidney disease, and food allergies, using Food and Drug Association (FDA) nutrition label reading guidance, and Word Health Organization (WHO) daily nutrition intake guidance.
              </p>
            </div>

            <div className="card feature-card">
              <div className="feature-icon-wrapper">
                <GitCompare size={24} />
              </div>
              <h3 className="feature-title">Product Comparison & Ranking</h3>
              <p>
                Compares and ranks up to multiple products based on their suitability to your health profile, recommending the best choice for your health condition.
              </p>
            </div>

            <div className="card feature-card">
              <div className="feature-icon-wrapper">
                <Mic size={24} />
              </div>
              <h3 className="feature-title">Voice Assistance</h3>
              <p>
                Offers hands-free navigation through voice commands supporting English and Tagalog languge, read-aloud, text size adjustment, color theme, and haptic feedback features to support accessibility.
              </p>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}

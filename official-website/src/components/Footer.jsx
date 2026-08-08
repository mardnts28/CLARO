import { Link } from 'react-router-dom';
import { Mail, GitBranch } from 'lucide-react';
import logoImg from '../assets/images/logoII.png';
import './Footer.css';

export default function Footer() {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="footer">
      <div className="container">
        <div className="footer-grid">
          {/* Brand Info Column */}
          <div className="footer-brand">
            <img src={logoImg} alt="CLARO Logo" className="footer-logo" />
            <p className="footer-description">
              Smart food recognition and nutrition guidance capstone project platform designed to empower healthier food choices.
            </p>
            <div className="footer-socials">
              <span className="social-icon-btn" title="Contact Email Placeholder" aria-label="Email">
                <Mail size={16} />
              </span>
              <span className="social-icon-btn" title="Repository Placeholder" aria-label="Repository">
                <GitBranch size={16} />
              </span>
            </div>
          </div>

          {/* Quick Links Column */}
          <div>
            <h4 className="footer-heading">Quick Links</h4>
            <ul className="footer-links">
              <li>
                <Link to="/" className="footer-link">Home</Link>
              </li>
              <li>
                <Link to="/user-guide" className="footer-link">User Guide</Link>
              </li>
              <li>
                <Link to="/about-developers" className="footer-link">About the Developers</Link>
              </li>
            </ul>
          </div>

          {/* Legal Links Column */}
          <div>
            <h4 className="footer-heading">Legal & Info</h4>
            <ul className="footer-links">
              <li>
                <Link to="/privacy-policy" className="footer-link">Privacy Policy</Link>
              </li>
              <li>
                <Link to="/terms-and-conditions" className="footer-link">Terms & Conditions</Link>
              </li>
            </ul>
          </div>
        </div>

        {/* Footer Bottom Bar */}
        <div className="footer-bottom">
          <p>© {currentYear} CLARO Capstone Project. All rights reserved.</p>
          <div className="footer-bottom-links">
            <Link to="/privacy-policy" className="footer-link">Privacy</Link>
            <Link to="/terms-and-conditions" className="footer-link">Terms</Link>
            <a href="http://localhost:5174/login" className="footer-link" target="_blank" rel="noopener noreferrer">Admin</a>
          </div>
        </div>
      </div>
    </footer>
  );
}

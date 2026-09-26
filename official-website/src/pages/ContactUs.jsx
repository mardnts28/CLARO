import { useRef, useState } from 'react';
import emailjs from '@emailjs/browser';
import { User, Send, Mail } from 'lucide-react';
import { EMAILJS_SERVICE_ID, EMAILJS_TEMPLATE_ID, EMAILJS_PUBLIC_KEY, CONTACT_RECIPIENT_EMAIL } from '../config/emailConfig';
import './Pages.css';

export default function ContactUs() {
  const formRef = useRef(null);
  const [status, setStatus] = useState('idle'); // idle | sending | success | error

  const developers = [
    {
      name: 'Mary Faith Ardientes',
      email: 'maryfaithardientes13@gmail.com',
      role: 'Project Manager & Machine Learning Engineer',
      image: 'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704181/ardientes_wrfpjz.jpg',
      icon: <User size={36} />,
      bio: 'Lead project manager overseeing strategic execution, team coordination, system requirements, and capstone milestone deliverables. Also, Machine Learning Engineer responsible for model training, validation, evaluation, and integration.',
      socials: {
        facebook: 'https://www.facebook.com/mary.ardientes',
        instagram: 'https://www.instagram.com/___mry.a?igsh=MXEzYXdtcXRnNjNv',
        github: 'https://github.com/mardnts28?fbclid=IwY2xjawTmmpVwZG9mBWV4dG4DYWVtAjEwAGJyaWQRMUxiUXUzeDhUSGJZQ0xlelRzcnRjBmFwcF9pZBAyMjIwMzkxNzg4MjAwODkyAAEeFmVD4rKFMmaq4btW2_2DYaryT6Po5gUhCLiUoCjS2yAWE_44_Uq4SKWkjYs_aem_Yuj8BcpgNQIfj5QdFyeBTQ',
        linkedin: 'https://www.linkedin.com/in/ardientes-mary-faith-aa8598315'
      }
    },
    {
      name: 'Jay Bhie Bite',
      email: 'bitejb6@gmail.com',
      role: 'UI/UX Designer & Developer',
      image: 'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704181/bite_vbnfzg.jpg',
      bio: 'UI/UX Designer focusing on user research, wireframing, interface design, and a consistent mobile/web experience. Also responsible for accessibility features for low-vision users, including light/dark themes, adjustable text size and speech volume, and English and Tagalog language support',
      socials: {
        facebook: 'https://www.facebook.com/share/1HWeEZRHYK/',
        instagram: 'https://www.instagram.com/jbbite?igsh=MTJzdm1xYnBkb3RxZw==',
        github: 'https://github.com/0910bayts',
        linkedin: 'https://www.linkedin.com/in/jay-bhie-bite-0462a1339?utm_source=share_via&utm_content=profile&utm_medium=member_android&fbclid=IwY2xjawTmmv1wZG9mBWV4dG4DYWVtAjEwAGJyaWQRMUxiUXUzeDhUSGJZQ0xlelRzcnRjBmFwcF9pZBAyMjIwMzkxNzg4MjAwODkyAAEe6WivYG0WfCMpWX3z49ySPCgDXqnOoxDsmEcVjIiFful9WGQ8_13osC_9Q0g_aem_vf_XxuScw-DbyplPovKb-Q'
      }
    },
    {
      name: 'Rochelle Ann C. Salucop',
      email: 'poculas.nna@gmail.com',
      role: 'Backend Developer & Quality Tester',
      image: 'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704183/salucop_mvd2zk.jpg',
      bio: 'Backend Developer responsible for developing and maintaining the application\'s backend services, database operations, nutrition data integration, server-side processing, and conducting quality testing to identify and resolve system issues',
      socials: {
        facebook: 'https://www.facebook.com/share/1b3eKUXKbK/',
        instagram: 'https://www.instagram.com/sea.chellie/',
        github: 'https://github.com/poculas',
        linkedin: 'https://www.linkedin.com/in/rochelle-ann-salucop-13621a280/'
      }
    }
  ];

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!formRef.current) return;

    setStatus('sending');

    emailjs
      .sendForm(EMAILJS_SERVICE_ID, EMAILJS_TEMPLATE_ID, formRef.current, {
        publicKey: EMAILJS_PUBLIC_KEY,
      })
      .then(() => {
        setStatus('success');
        formRef.current.reset();
      })
      .catch((error) => {
        console.error('EmailJS send error:', error);
        setStatus('error');
      });
  };

  return (
    <div className="contact-us-page page-section" style={{ paddingTop: 0 }}>
      <div className="container">
        {/* Contact Us Section */}
        <div className="page-header">
          <h1 className="page-title">Contact Us</h1>
          <p className="page-subtitle">
            Have a question, feedback, or concern about CLARO? Send us a message below.
          </p>
        </div>

        <div className="card contact-form-card">
          <form className="contact-form" ref={formRef} onSubmit={handleSubmit}>
            {/* Hidden field so the existing EmailJS template can route the message */}
            <input type="hidden" name="to_email" value={CONTACT_RECIPIENT_EMAIL} />

            <div className="form-group">
              <label className="form-label" htmlFor="contact-name">Name</label>
              <input
                id="contact-name"
                name="from_name"
                type="text"
                className="form-input"
                placeholder="Your full name"
                required
              />
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="contact-email">Email Address</label>
              <input
                id="contact-email"
                name="from_email"
                type="email"
                className="form-input"
                placeholder="you@example.com"
                required
              />
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="contact-message">Message</label>
              <textarea
                id="contact-message"
                name="message"
                className="form-textarea"
                placeholder="Write your message here..."
                required
              />
            </div>

            <div className="contact-form-actions">
              <button type="submit" className="btn-primary" disabled={status === 'sending'}>
                <Send size={18} />
                {status === 'sending' ? 'Sending...' : 'Send Message'}
              </button>

              {status === 'success' && (
                <span className="contact-form-status success">
                  Your message has been sent. Thank you!
                </span>
              )}
              {status === 'error' && (
                <span className="contact-form-status error">
                  Something went wrong. Please try again later.
                </span>
              )}
            </div>
          </form>
        </div>

        {/* About the Developers Section */}
        <div className="page-header" style={{ marginTop: '5rem' }}>
          <h2 className="section-title">About the Developers</h2>
          <p className="page-subtitle">
            We are 4th year Bachelor of Science in Information Technology (BSIT) students from Technological Institute of the Philippines (TIP) - Manila Campus, whom developed CLARO for our Capstone Project
          </p>
        </div>

        {/* Developer Team Cards Grid */}
        <div className="developers-grid">
          {developers.map((dev, idx) => (
            <div className="card developer-card" key={idx}>
              {dev.image ? (
                <img
                  src={dev.image}
                  alt={dev.name}
                  className="developer-avatar-img"
                  loading="lazy"
                />
              ) : (
                <div className="developer-avatar-placeholder" aria-label="Developer avatar placeholder">
                  {dev.icon}
                </div>
              )}
              <h3 className="developer-name">{dev.name}</h3>
              <p className="developer-email">
                <Mail size={14} style={{ marginRight: '6px', verticalAlign: 'middle' }} />
                {dev.email}
              </p>
              <p className="developer-role">{dev.role}</p>
              <p className="developer-bio">{dev.bio}</p>

              {/* Social Media Icons */}
              <div className="developer-socials">
                <a href={dev.socials.facebook} className="developer-social-link" aria-label={`${dev.name} Facebook`} target="_blank" rel="noopener noreferrer">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z"/>
                  </svg>
                </a>
                <a href={dev.socials.instagram} className="developer-social-link" aria-label={`${dev.name} Instagram`} target="_blank" rel="noopener noreferrer">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <rect width="20" height="20" x="2" y="2" rx="5" ry="5"/>
                    <path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z"/>
                    <line x1="17.5" x2="17.51" y1="6.5" y2="6.5"/>
                  </svg>
                </a>
                <a href={dev.socials.github} className="developer-social-link" aria-label={`${dev.name} GitHub`} target="_blank" rel="noopener noreferrer">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M15 22v-4a4.8 4.8 0 0 0-1-3.5c3 0 6-2 6-5.5.08-1.25-.27-2.48-1-3.5.28-1.15.28-2.35 0-3.5 0 0-1 0-3 1.5-2.64-.5-5.36-.5-8 0C6 2 5 2 5 2c-.3 1.15-.3 2.35 0 3.5A5.403 5.403 0 0 0 4 9c0 3.5 3 5.5 6 5.5-.39.49-.68 1.05-.85 1.65-.17.6-.22 1.23-.15 1.85v4"/>
                    <path d="M9 18c-4.51 2-5-2-7-2"/>
                  </svg>
                </a>
                <a href={dev.socials.linkedin} className="developer-social-link" aria-label={`${dev.name} LinkedIn`} target="_blank" rel="noopener noreferrer">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M16 8a6 6 0 0 1 6 6v7h-4v-7a2 2 0 0 0-2-2 2 2 0 0 0-2 2v7h-4v-7a6 6 0 0 1 6-6z"/>
                    <rect width="4" height="12" x="2" y="9"/>
                    <circle cx="4" cy="4" r="2"/>
                  </svg>
                </a>
              </div>
            </div>
          ))}
        </div>

      </div>
    </div>
  );
}

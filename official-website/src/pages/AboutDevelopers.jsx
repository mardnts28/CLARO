import { User } from 'lucide-react';
import ImageCarousel from '../components/ImageCarousel';
import biteImg from '../assets/images/developers/bite.jpg';
import salucopImg from '../assets/images/developers/salucop.png';
import './Pages.css';

export default function AboutDevelopers() {
  const developers = [
    {
      name: 'Mary Faith Ardientes',
      role: 'Project Manager',
      image: null,
      icon: <User size={36} />,
      bio: 'Lead project manager overseeing strategic execution, team coordination, system requirements, and capstone milestone deliverables.',
      socials: {
        facebook: '#',
        instagram: '#',
        github: '#',
        linkedin: '#'
      }
    },
    {
      name: 'Jay Bhie Bite',
      role: 'UI/UX Designer',
      image: 'images/developers/bite.jpg',
      fallbackImage: biteImg,
      bio: 'Creative UI/UX designer focusing on user research, wireframing, interface design system, and overall mobile/web user experience.',
      socials: {
        facebook: '#',
        instagram: '#',
        github: '#',
        linkedin: '#'
      }
    },
    {
      name: 'Rochelle Ann C. Salucop',
      role: 'Backend Developer',
      image: 'images/developers/salucop.png',
      fallbackImage: salucopImg,
      bio: 'Backend engineer specializing in API architecture, database optimization, nutrition data integration, and server-side processing.',
      socials: {
        facebook: '#',
        instagram: '#',
        github: '#',
        linkedin: '#'
      }
    }
  ];

  return (
    <div className="about-developers-page page-section" style={{ paddingTop: 0 }}>
      {/* Auto-scrolling image header banner above page title */}
      <ImageCarousel />

      <div className="container">
        {/* Page Header */}
        <div className="page-header">
          <span className="badge" style={{ marginBottom: '0.75rem' }}>Capstone Team</span>
          <h1 className="page-title">About the Developers</h1>
          <p className="page-subtitle">
            Meet the student development team behind the CLARO smart food recognition project.
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
                  onError={(e) => {
                    if (dev.fallbackImage && e.target.src !== dev.fallbackImage) {
                      e.target.src = dev.fallbackImage;
                    }
                  }}
                />
              ) : (
                <div className="developer-avatar-placeholder" aria-label="Developer avatar placeholder">
                  {dev.icon}
                </div>
              )}
              <h3 className="developer-name">{dev.name}</h3>
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

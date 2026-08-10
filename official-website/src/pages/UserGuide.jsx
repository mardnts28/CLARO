import { BookOpen, Camera, BarChart2, GitCompare, AlertTriangle, FileText } from 'lucide-react';
import './Pages.css';

export default function UserGuide() {
  const guideTopics = [
    {
      title: 'Getting Started',
      icon: <BookOpen size={24} />,
      desc: 'Placeholder overview of basic setup, account creation, and initial app configuration instructions.'
    },
    {
      title: 'How to Scan',
      icon: <Camera size={24} />,
      desc: 'Placeholder guidelines on camera positioning, optimal lighting, and scanning techniques for accurate recognition.'
    },
    {
      title: 'Understanding Results',
      icon: <BarChart2 size={24} />,
      desc: 'Placeholder breakdown explaining nutritional figures, macro distribution, and dietary recommendation indicators.'
    },
    {
      title: 'Product Comparison',
      icon: <GitCompare size={24} />,
      desc: 'Placeholder explanation of comparing two or more food items side-by-side for healthier decision making.'
    },
    {
      title: 'Health Advisory',
      icon: <AlertTriangle size={24} />,
      desc: 'Placeholder instructions regarding allergen warnings, dietary restrictions, and health advisories.'
    }
  ];

  return (
    <div className="user-guide-page page-section">
      <div className="container">
        {/* Page Header */}
        <div className="page-header">
          <h1 className="page-title">User Guide</h1>
          <p className="page-subtitle">
            Comprehensive placeholder documentation and walkthrough guides for using the CLARO application.
          </p>
        </div>

        {/* Large Guide Content Placeholder Area */}
        <div className="placeholder-box-lg">
          <FileText size={48} style={{ color: 'var(--primary-red)', marginBottom: '1rem' }} />
          <h3>Interactive Guide Preview Area</h3>
          <p style={{ maxWidth: '520px', margin: '0.5rem auto 0' }}>
            This main content container is reserved for future step-by-step documentation, video walkthroughs, and detailed usage instructions.
          </p>
        </div>

        {/* Guide Topic Cards Section */}
        <div className="section-header">
          <h2 className="section-title">Guide Topics</h2>
          <p className="section-subtitle">
            Explore key topics that will be detailed in the full CLARO user guide.
          </p>
        </div>

        <div className="cards-grid-3">
          {guideTopics.map((topic, idx) => (
            <div className="card feature-card" key={idx}>
              <div className="feature-icon-wrapper">
                {topic.icon}
              </div>
              <h3 className="feature-title">{topic.title}</h3>
              <p>{topic.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

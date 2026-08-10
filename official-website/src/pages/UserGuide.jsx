import { useState } from 'react';
import { Camera, BarChart2, GitCompare, Mic } from 'lucide-react';
import './Pages.css';

export default function UserGuide() {
  const [expandedCard, setExpandedCard] = useState(null);

  const toggleCard = (cardId) => {
    setExpandedCard(expandedCard === cardId ? null : cardId);
  };

  const guideCards = [
    {
      id: 1,
      title: 'How to Scan',
      icon: <Camera size={24} />,
      content: (
        <div className="guide-content">
          <h4>How to Scan</h4>
          <ol>
            <li>
              <strong>Open the Scan Tab</strong>
              <p>Tap the "Scan" button at the bottom of the screen or from the dashboard to access the camera.</p>
            </li>
            <li>
              <strong>Position Your Product</strong>
              <p>Hold the product or steady the camera so it fits within the on-screen guide frame.</p>
            </li>
            <li>
              <strong>Wait for Detection</strong>
              <p>The app will automatically detect when the product is properly positioned. You will see visual feedback.</p>
            </li>
            <li>
              <strong>Capture</strong>
              <p>Let the auto-capture trigger when the product is steadily within the frame.</p>
            </li>
            <li>
              <strong>Get Results</strong>
              <p>The app will immediately analyze and display the product information.</p>
            </li>
          </ol>
          <div className="tips-section">
            <h5>Tips for Better Scanning</h5>
            <ul>
              <li>Ensure good lighting.</li>
              <li>Hold the camera steady.</li>
              <li>Make sure the product label is clearly visible.</li>
              <li>Avoid glare or reflections on the label.</li>
            </ul>
          </div>
        </div>
      )
    },
    {
      id: 2,
      title: 'Understanding the Results',
      icon: <BarChart2 size={24} />,
      content: (
        <div className="guide-content">
          <h4>Understanding the Results</h4>
          <p>After scanning, you'll see a detailed product analysis with the following information:</p>
          
          <div className="result-section">
            <h5>Product Identification</h5>
            <ul>
              <li>FDA Registration Number (CPR) and its expiry date</li>
              <li>Product name and image</li>
              <li>Brand information</li>
              <li>Serving size details</li>
            </ul>
          </div>

          <div className="result-section">
            <h5>Health Grade (Nutri-Score)</h5>
            <ul>
              <li><strong>Best (Green)</strong> — Highly nutritious, recommended choice</li>
              <li><strong>Recommended (Yellow)</strong> — Good nutritional value</li>
              <li><strong>Acceptable (Orange)</strong> — Fine in moderation</li>
              <li><strong>Limit (Red)</strong> — Should be consumed in limited amounts</li>
              <li><strong>Avoid (Dark Red)</strong> — Avoid frequent intake</li>
            </ul>
          </div>

          <div className="result-section">
            <h5>Nutrition Breakdown</h5>
            <ul>
              <li>Calories per serving</li>
              <li>Sugar content compared to WHO daily limits</li>
              <li>Salt/sodium levels</li>
              <li>Saturated and trans fats</li>
              <li>Protein and fiber content</li>
            </ul>
          </div>

          <div className="result-section">
            <h5>Personalized Health Advisory</h5>
            <ul>
              <li>Warnings based on your health conditions, such as diabetes and hypertension</li>
              <li>Allergen alerts specific to your profile</li>
              <li>Recommendations tailored to your dietary needs</li>
            </ul>
          </div>

          <div className="result-section">
            <h5>Processing Level (NOVA Classification)</h5>
            <ul>
              <li><strong>Unprocessed/Minimally Processed</strong> — Best choice</li>
              <li><strong>Processed Culinary Ingredients</strong> — Good in moderation</li>
              <li><strong>Processed</strong> — Acceptable occasionally</li>
              <li><strong>Ultra-Processed</strong> — Limit consumption</li>
            </ul>
          </div>
        </div>
      )
    },
    {
      id: 3,
      title: 'How to Compare Products',
      icon: <GitCompare size={24} />,
      content: (
        <div className="guide-content">
          <h4>How to Compare Products</h4>
          
          <div className="comparison-section">
            <h5>Single Product Comparison</h5>
            <ol>
              <li>After scanning a product, tap the "Compare" button.</li>
              <li>The app will show similar products in the same category.</li>
              <li>Products are ranked from best to worst based on your health profile.</li>
              <li>Browse the ranked list and tap any product to see detailed information.</li>
            </ol>
          </div>

          <div className="comparison-section">
            <h5>Multi-Scan Comparison</h5>
            <ol>
              <li>Enable multi-scan mode in the camera screen.</li>
              <li>Scan multiple products, up to 5, in one session.</li>
              <li>Tap "Compare Results" after scanning.</li>
              <li>View the side-by-side ranking with personalized recommendations.</li>
              <li>The app highlights the best choice for your specific health conditions.</li>
            </ol>
          </div>

          <div className="comparison-section">
            <h5>Comparison Features</h5>
            <ul>
              <li><strong>Health-Based Ranking</strong> — Products are scored based on your conditions.</li>
              <li><strong>Filter by Condition</strong> — Focus on specific health concerns, such as "Best for Diabetes."</li>
              <li><strong>Search Function</strong> — Find specific products in the comparison list.</li>
              <li><strong>Detailed View</strong> — Tap any product to see the full nutrition analysis.</li>
            </ul>
          </div>
        </div>
      )
    },
    {
      id: 4,
      title: 'How to Use Voice Assistant',
      icon: <Mic size={24} />,
      content: (
        <div className="guide-content">
          <h4>How to Use Voice Assistant</h4>
          
          <div className="voice-section">
            <h5>Enable Voice Assistant</h5>
            <ol>
              <li>Go to Profile → Preferences.</li>
              <li>Toggle "Voice Assistant" to enable it.</li>
              <li>Grant microphone permissions when prompted.</li>
              <li>Choose your preferred language: English or Tagalog.</li>
              <li>Adjust the speech rate for comfortable listening.</li>
            </ol>
          </div>

          <div className="voice-section">
            <h5>Voice Commands</h5>
            <p>The voice assistant responds to natural commands.</p>
            
            <div className="command-category">
              <h6>Navigation</h6>
              <ul>
                <li>"Go to home" / "Home"</li>
                <li>"Go to scan" / "Scan"</li>
                <li>"Go to history" / "History"</li>
                <li>"Go to profile" / "Profile"</li>
              </ul>
            </div>

            <div className="command-category">
              <h6>Profile & Settings</h6>
              <ul>
                <li>"Go to personal info" / "Personal information"</li>
                <li>"Go to preferences" / "Settings"</li>
                <li>"Go to about CLARO" / "About"</li>
              </ul>
            </div>

            <div className="command-category">
              <h6>Actions</h6>
              <ul>
                <li>"Scan product" / "Start scanning"</li>
                <li>"Compare products" / "Compare"</li>
                <li>"Read results" / "Tell me about this product"</li>
              </ul>
            </div>
          </div>

          <div className="voice-section">
            <h5>Voice Assistant Features</h5>
            <ul>
              <li><strong>Screen Reading</strong> — Automatically announces page content when you navigate.</li>
              <li><strong>Hands-Free Operation</strong> — Navigate the app without touching the screen.</li>
              <li><strong>Accessibility</strong> — Designed for users with visual impairments.</li>
              <li><strong>Bilingual Support</strong> — Works in both English and Tagalog.</li>
              <li><strong>Adjustable Speed</strong> — Control how fast the assistant speaks.</li>
            </ul>
          </div>

          <div className="voice-section">
            <h5>Using the Microphone Button</h5>
            <ol>
              <li>Tap the microphone button (floating action button) to activate voice commands.</li>
              <li>Speak clearly and wait for the acknowledgment before continuing.</li>
              <li>The assistant will confirm what it heard before executing commands.</li>
            </ol>
          </div>

          <div className="tips-section">
            <h5>Tips for Voice Assistant</h5>
            <ul>
              <li>Speak in a quiet environment for better recognition.</li>
              <li>Use simple, direct commands.</li>
              <li>Wait for the assistant to finish speaking before giving the next command.</li>
              <li>The assistant works best with the phrases listed above.</li>
            </ul>
          </div>
        </div>
      )
    }
  ];

  return (
    <div className="user-guide-page page-section">
      <div className="container">
        {/* Page Header */}
        <div className="page-header">
          <h1 className="page-title">User Guide</h1>
          <p className="page-subtitle">
            Comprehensive documentation and walkthrough guides for using the CLARO application.
          </p>
        </div>

        {/* User Guide Cards - Single Column Vertical List */}
        <div className="guide-cards-vertical">
          {guideCards.map((card) => (
            <div 
              key={card.id} 
              className={`guide-card ${expandedCard === card.id ? 'expanded' : ''}`}
            >
              <div className="guide-card-header">
                <div className="guide-card-title-wrapper">
                  <div className="guide-card-icon">{card.icon}</div>
                  <h3 className="guide-card-title">{card.title}</h3>
                </div>
                <button 
                  className="guide-card-toggle"
                  onClick={() => toggleCard(card.id)}
                >
                  {expandedCard === card.id ? 'View Less' : 'View More'}
                </button>
              </div>
              {expandedCard === card.id && (
                <div className="guide-card-body">
                  {card.content}
                </div>
              )}
            </div>
          ))}
        </div>

        {/* Additional Help Section */}
        <div className="additional-help-section">
          <h3 className="additional-help-title">Additional Help</h3>
          <ul className="additional-help-list">
            <li>View your scan history in the History tab.</li>
            <li>Access FDA and WHO nutrition guides from the dashboard.</li>
            <li>Submit unknown products for future database inclusion.</li>
            <li>Customize your health profile in Profile → Personal Info for better recommendations.</li>
          </ul>
        </div>
      </div>
    </div>
  );
}

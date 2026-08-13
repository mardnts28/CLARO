import { useState } from 'react';
import { Camera, BarChart2, GitCompare, Mic, ChevronDown, ChevronUp, PackageSearch } from 'lucide-react';
import './Pages.css';

export default function UserGuide() {
  const [expandedCard, setExpandedCard] = useState(null);

  const toggleCard = (cardId) => {
    setExpandedCard(expandedCard === cardId ? null : cardId);
  };

  // Products currently supported by the CLARO recognition model, as of August 14, 2026.
  // Each category's product list is sorted alphabetically.
  // Product data sourced from Ever Plus Superstore Inc., Dela Fuente St., Sampaloc, Manila
  // in early week of August 2026 with the consent and supervision of the store branch's supervisor and manager.
  const supportedProducts = [
    {
      category: 'Canned Fish',
      products: [
        '555 Flakes in Oil Tuna',
        '555 Fried Sardines Hot and Spicy',
        '555 Hot and Spicy Tuna',
        '555 Sardines Escabeche',
        '555 Spicy Bicol Express',
        '555 Tomato Sauce',
        '555 Tuna Adobo',
        '555 Tuna Caldereta',
        'Blue Bay Corned Tuna Hot and Spicy',
        'Blue Bay Original',
        'Century Tuna Flakes and Oil',
        'Century Tuna Hot and Spicy',
        'Century Tuna with Calamansi',
        'Golden Town Tomato Sauce',
        'Ligo Sardines Tomato Sauce',
        'Ligo Sardines Tomato Sauce Chili Added',
        'Mega Sardines Tomato Sauce',
        'Mega Sardines Tomato Sauce Chili Added',
        'Mega Tuna Hot and Spicy'
      ]
    },
    {
      category: 'Canned Meat',
      products: [
        'Argentina Beef Loaf',
        'Argentina Corned Beef',
        'CDO Home Styled Corned Beef',
        'CDO Karne Norte Classic',
        'LM Beef Chili Mansi',
        'LM Beef Na Beef',
        'LM Chicken Chili Mansi',
        'LM Chicken Na Chicken',
        'LM PC Chili Mansi',
        'LM PC Chili Mansi Kasalo PCK',
        'LM PC Extra Hot Chili',
        'LM PC Extra Hot Chili Kasalo PCK',
        'LM PC Kalamansi',
        'LM PC Original',
        'LM PC Sweet and Spicy',
        'Lucky 7 Carne Norte',
        'Purefoods Chicken Luncheon Meat',
        'Purefoods Corned Beef Hot and Spicy',
        'Purefoods Corned Beef with Chunks',
        'Purefoods Liver Spread',
        'San Marino Corned',
        'San Marino Corned Chili',
        'Spicy Labuyo Beef',
        'Spicy Labuyo Chicken'
      ]
    },
    {
      category: 'Canned Seafood',
      products: [
        'Unipack Squid'
      ]
    },
    {
      category: 'Canned Vegetables',
      products: [
        'DM Fiesta Fruit Cocktail',
        'DM Fruit Cocktail Heavy Syrup',
        'DM Pineapple Tidbits',
        'Jolly Mushroom',
        'Mega Prime Green Peas',
        'Ram Green Peas',
        'Saba Soy Sauce',
        'Saba Soy Sauce with Chili',
        'UFC Green Peas'
      ]
    },
    {
      category: 'Instant Noodles',
      products: [
        'Suy Foods Chick-N-De-Lata Chicken Giniling',
        'Suy Foods Chick-N-De-Lata Chicken Pastil',
        'Suy Foods Chick-N-De-Lata Chicken Sisig'
      ]
    }
  ];

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
    },
    {
      id: 5,
      title: 'What to Do if Product is Unrecognized?',
      icon: <PackageSearch size={24} />,
      content: (
        <div className="guide-content">
          <h4>What to Do if Product is Unrecognized?</h4>
          <p>
            Sometimes CLARO may not recognize the product you scanned, or it may recognize it
            incorrectly and show the wrong product on the Product Detail screen. This can happen
            if the product isn't in our database yet, or if the packaging is hard to read from the photo.
          </p>

          <div className="result-section">
            <h5>How to Report the Issue</h5>
            <ol>
              <li>
                <strong>Take a Front Photo</strong>
                <p>Capture a clear photo of the front of the product packaging.</p>
              </li>
              <li>
                <strong>Take a Back Photo</strong>
                <p>Capture a clear photo of the back of the product, preferably showing the nutrition and product information.</p>
              </li>
              <li>
                <strong>Submit the Report Form</strong>
                <p>Complete and submit the report using the Report feature so our team can review it.</p>
              </li>
            </ol>
          </div>

          <div className="tips-section">
            <h5>Why Reporting Helps</h5>
            <ul>
              <li>Expands the number of products supported by the recognition model.</li>
              <li>Improves recognition accuracy over time.</li>
              <li>Reduces incorrect product identifications.</li>
              <li>Continuously improves CLARO's product database and recognition capabilities.</li>
            </ul>
          </div>

          <div className="result-section">
            <h5>Products Currently Supported by the Recognition Model — As of August 14, 2026</h5>
            <p className="supported-products-date">
              The list below reflects the products CLARO's recognition model can currently identify, as of <strong>August 14, 2026</strong>. These products were sourced from <strong>Ever Plus Superstore Inc., Dela Fuente St., Sampaloc, Manila</strong> in the early week of August 2026 with the consent and supervision of the store branch's supervisor and manager. If a product isn't listed here, please submit a report so we can add it.
            </p>
            <div className="supported-products-grid">
              {supportedProducts.map((group) => (
                <div className="command-category" key={group.category}>
                  <h6>{group.category}</h6>
                  {group.products.length > 0 ? (
                    <ul>
                      {group.products.map((product) => (
                        <li key={product}>{product}</li>
                      ))}
                    </ul>
                  ) : (
                    <p className="supported-products-empty">List pending — no products confirmed yet.</p>
                  )}
                </div>
              ))}
            </div>
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
                  className="guide-card-toggle guide-card-toggle-icon"
                  onClick={() => toggleCard(card.id)}
                  title={expandedCard === card.id ? 'View Less' : 'View More'}
                  aria-label={expandedCard === card.id ? 'View Less' : 'View More'}
                  aria-expanded={expandedCard === card.id}
                >
                  {expandedCard === card.id ? <ChevronUp size={20} /> : <ChevronDown size={20} />}
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
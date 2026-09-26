import './AboutClaro.css';

const ABOUT_DESCRIPTION =
  "CLARO is an AI-powered mobile app that helps grocery shoppers understand nutrition information for local canned foods. By scanning a product, users see simplified nutrition summaries, health advisories, allergen warnings, product comparisons, and accessibility features such as voice assistance to make smarter and healthier buying decisions.";

export default function AboutClaro() {
  return (
    <section className="page-section about-claro-section">
      <div className="container about-claro-container">
        <h2 className="section-title about-claro-title">About CLARO</h2>
        <p className="about-claro-text">{ABOUT_DESCRIPTION}</p>
      </div>
    </section>
  );
}

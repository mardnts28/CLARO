import { useCallback, useEffect, useRef, useState } from 'react';
import scanScreenImg from '../assets/featureSS/scanScreen.png';
import analysisImg from '../assets/featureSS/analysis.png';
import compareImg from '../assets/featureSS/compare.png';
import './AboutClaroWorks.css';

const AUTO_ADVANCE_MS = 6500;

const ABOUT_DESCRIPTION =
  "CLARO is an AI-powered mobile app that helps grocery shoppers understand nutrition information for local canned foods. By scanning a product, users see simplified nutrition summaries, health advisories, allergen warnings, product comparisons, and accessibility features such as voice assistance to make smarter and healthier buying decisions.";

const STEPS = [
  {
    number: '01',
    title: 'Point and Capture',
    description:
      "Aim your camera at a locally branded canned food or instant noodle product then tap anywhere on the screen to capture.",
    image: { src: scanScreenImg, alt: 'CLARO camera view recognizing a food product' },
  },
  {
    number: '02',
    title: 'Receive Analysis',
    description:
      "Instantly view the product's information, FDA registration and expiry date, complete ingredients and nutrition facts, Nutri-Score, NOVA classification, and a personalized Health Advisory.",
    image: { src: analysisImg, alt: 'Health analysis showing sodium, sugar and saturated fat levels' },
  },
  {
    number: '03',
    title: 'Compare Products',
    description:
      'Scan multiple products or tap Compare to see a ranked list of similar items, complete with clear recommendations to help you choose the healthier option.',
    image: { src: compareImg, alt: 'Ranked comparison of similar products with recommendations' },
  },
];

export default function AboutClaroWorks() {
  const [currentStep, setCurrentStep] = useState(0);
  const [isPaused, setIsPaused] = useState(false);
  const timerRef = useRef(null);

  const goToStep = useCallback((index) => {
    setCurrentStep(index);
  }, []);

  useEffect(() => {
    if (isPaused) return undefined;
    timerRef.current = setTimeout(() => {
      setCurrentStep((prev) => (prev + 1) % STEPS.length);
    }, AUTO_ADVANCE_MS);
    return () => clearTimeout(timerRef.current);
  }, [currentStep, isPaused]);

  const step = STEPS[currentStep];

  return (
    <section
      className="page-section about-claro-section"
      onMouseEnter={() => setIsPaused(true)}
      onMouseLeave={() => setIsPaused(false)}
      onFocus={() => setIsPaused(true)}
      onBlur={() => setIsPaused(false)}
    >
      <div className="container about-claro-grid">
        {/* Left column: About CLARO */}
        <div className="about-claro-left">
          <h2 className="section-title">About CLARO</h2>
          <p className="about-claro-text">{ABOUT_DESCRIPTION}</p>
        </div>

        {/* Right column: How CLARO Works walkthrough */}
        <div className="about-claro-right">
          <div className="steps-rail" role="tablist" aria-label="How CLARO Works steps">
            {STEPS.map((s, i) => (
              <div className="steps-rail-item" key={s.number}>
                <button
                  type="button"
                  role="tab"
                  aria-selected={i === currentStep}
                  aria-label={`Step ${s.number}: ${s.title}`}
                  className={`steps-rail-dot${i === currentStep ? ' is-active' : ''}${
                    i < currentStep ? ' is-complete' : ''
                  }`}
                  onClick={() => goToStep(i)}
                >
                  {s.number}
                </button>
                {i < STEPS.length - 1 && (
                  <span className={`steps-rail-line${i < currentStep ? ' is-filled' : ''}`} />
                )}
              </div>
            ))}
          </div>

          <div key={currentStep} className="step-content">
            <img src={step.image.src} alt={step.image.alt} loading="lazy" className="step-image" />
            <div className="step-info">
              <span className="step-label">Step {step.number}</span>
              <h3 className="step-title">{step.title}</h3>
              <p className="step-description">{step.description}</p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

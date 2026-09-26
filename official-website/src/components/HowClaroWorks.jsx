import { useEffect, useRef, useState } from 'react';
import scanScreenImg from '../assets/featureSS/scanScreen.png';
import analysisImg from '../assets/featureSS/analysis.png';
import compareImg from '../assets/featureSS/compare.png';
import aboutBgImg from '../assets/images/aboutBg.jpg';
import './HowClaroWorks.css';

const STEPS = [
  {
    number: '01',
    title: 'Point and Capture',
    description:
      "Aim your camera at a locally branded canned food or instant noodle product then tap anywhere on the screen to capture.",
    images: [
      { src: scanScreenImg, alt: 'CLARO camera view recognizing a food product' },
 ],
    layout: 'image-left' // Step 1: Images on left, text on right
  },
  {
    number: '02',
    title: 'Receive Analysis',
    description:
      "Instantly view the product's information, FDA registration and expiry date, complete ingredients and nutrition facts, Nutri-Score, NOVA classification, and a personalized Health Advisory.",
    images: [
      { src: analysisImg, alt: 'Health analysis showing sodium, sugar and saturated fat levels' },
    ],
    layout: 'image-right' // Step 2: Text on left, images on right
  },
  {
    number: '03',
    title: 'Compare Products',
    description:
      'Scan multiple products or tap Compare to see a ranked list of similar items, complete with clear recommendations to help you choose the healthier option.',
    images: [
      { src: compareImg, alt: 'Ranked comparison of similar products with recommendations' },
   ],
    layout: 'image-left' // Step 3: Images on left, text on right
  },
];

export default function HowClaroWorks() {
  const [visibleSteps, setVisibleSteps] = useState(new Set());
  const stepRefs = useRef([]);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            const stepIndex = parseInt(entry.target.dataset.stepIndex);
            setVisibleSteps((prev) => new Set([...prev, stepIndex]));
          }
        });
      },
      {
        threshold: 0.2,
        rootMargin: '0px 0px -100px 0px'
      }
    );

    stepRefs.current.forEach((ref) => {
      if (ref) observer.observe(ref);
    });

    return () => {
      stepRefs.current.forEach((ref) => {
        if (ref) observer.unobserve(ref);
      });
    };
  }, []);

  return (
    <section 
      className="page-section how-claro-works-section"
      style={{ backgroundImage: `url(${aboutBgImg})` }}
    >
      <div className="container">
        <h2 className="section-title how-claro-works-title">How CLARO Works</h2>
        
        <div className="steps-container">
          {STEPS.map((step, index) => (
            <div
              key={step.number}
              ref={(el) => (stepRefs.current[index] = el)}
              data-step-index={index}
              className={`step-row ${step.layout} ${visibleSteps.has(index) ? 'is-visible' : ''}`}
            >
              <div className="step-images">
                {step.images.map((img, imgIndex) => (
                  <img
                    key={imgIndex}
                    src={img.src}
                    alt={img.alt}
                    loading="lazy"
                    className="step-image"
                  />
                ))}
              </div>
              
              <div className="step-content">
                <span className="step-number">Step {step.number}</span>
                <h3 className="step-title">{step.title}</h3>
                <div className="step-description-card">
                  <p className="step-description">{step.description}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

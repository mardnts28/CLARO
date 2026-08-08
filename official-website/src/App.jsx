import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Navbar from './components/Navbar';
import Footer from './components/Footer';
import ScrollToTop from './components/ScrollToTop';

import Home from './pages/Home';
import UserGuide from './pages/UserGuide';
import PrivacyPolicy from './pages/PrivacyPolicy';
import TermsConditions from './pages/TermsConditions';
import AboutDevelopers from './pages/AboutDevelopers';

export default function App() {
  return (
    <Router>
      <ScrollToTop />
      <Navbar />
      <main className="main-content">
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/user-guide" element={<UserGuide />} />
          <Route path="/privacy-policy" element={<PrivacyPolicy />} />
          <Route path="/terms-and-conditions" element={<TermsConditions />} />
          <Route path="/about-developers" element={<AboutDevelopers />} />
          {/* Fallback to Home for unknown routes */}
          <Route path="*" element={<Home />} />
        </Routes>
      </main>
      <Footer />
    </Router>
  );
}

import { useEffect, useRef, useState } from "react";
import { FiShield } from "react-icons/fi";
import "./TurnstileWidget.css";

const SITE_KEY = import.meta.env.VITE_CLOUDFLARE_TURNSTILE_SITE_KEY;

export default function TurnstileWidget({ onVerify, onError, onExpire }) {
  const containerRef = useRef(null);
  const widgetIdRef = useRef(null);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    // If no site key is configured (local development or test environment),
    // automatically pass verification so local testing is never blocked.
    if (!SITE_KEY) {
      if (onVerify) onVerify("dev-bypass-token");
      return;
    }

    // Function to render the Turnstile widget
    const renderWidget = () => {
      if (window.turnstile && containerRef.current && widgetIdRef.current === null) {
        try {
          widgetIdRef.current = window.turnstile.render(containerRef.current, {
            sitekey: SITE_KEY,
            callback: (token) => {
              if (onVerify) onVerify(token);
            },
            "error-callback": () => {
              if (onError) onError();
            },
            "expired-callback": () => {
              if (onExpire) onExpire();
            },
            theme: "light",
          });
          setIsLoaded(true);
        } catch (e) {
          console.warn("Turnstile render note:", e);
        }
      }
    };

    // If Turnstile script is already on the page
    if (window.turnstile) {
      renderWidget();
      return;
    }

    // Inject Cloudflare Turnstile script
    const scriptId = "cf-turnstile-script";
    let script = document.getElementById(scriptId);

    if (!script) {
      script = document.createElement("script");
      script.id = scriptId;
      script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
      script.async = true;
      script.defer = true;
      script.onload = () => {
        renderWidget();
      };
      document.head.appendChild(script);
    } else {
      script.addEventListener("load", renderWidget);
    }

    return () => {
      if (widgetIdRef.current !== null && window.turnstile) {
        try {
          window.turnstile.remove(widgetIdRef.current);
        } catch (e) {
          // ignore
        }
        widgetIdRef.current = null;
      }
    };
  }, [onVerify, onError, onExpire]);

  if (!SITE_KEY) {
    return null;
  }

  return (
    <div className="turnstile-container">
      <div ref={containerRef} />
    </div>
  );
}

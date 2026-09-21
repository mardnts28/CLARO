# Cloudflare DDoS & Bot Protection Setup Guide for CLARO Admin

This document details the configuration for **Cloudflare DDoS Protection, Bot Fight Mode, and WAF Rate Limiting** to protect the CLARO Admin Dashboard against Denial of Service (DoS/DDoS) attacks, brute-force credential stuffing, and malicious scraping.

---

## 1. Cloudflare Proxy Setup (Orange Cloud)

1. Log in to your [Cloudflare Dashboard](https://dash.cloudflare.com/).
2. Add your custom domain (e.g., `admin.claro-app.com`) or select your existing active zone.
3. In **DNS Records**:
   * Add a `CNAME` pointing your admin subdomain to your host (e.g., Render `claro-admin.onrender.com`).
   * Ensure the **Proxy status** is set to **Proxied (Orange Cloud)**.
   * *Benefit:* Hides your origin server's real IP address, routing all incoming traffic through Cloudflare’s global Anycast network which automatically absorbs Layer 3 and Layer 4 DDoS attacks.

---

## 2. Enable Cloudflare Bot Fight Mode

Cloudflare Bot Fight Mode inspects incoming HTTP requests using machine learning heuristics and JavaScript challenges to stop automated scrapers, headless browsers, and credential-stuffing bots.

1. Navigate to **Security** > **Bots** in the Cloudflare Dashboard.
2. Toggle on **Bot Fight Mode**.
3. Under **Challenge Behavior**, ensure automated malicious bots receive an interactive challenge before they can touch the web app.

---

## 3. Configure WAF Rate Limiting Rules (Brute-Force & Flood Defense)

Protect the sensitive authentication endpoints from flood requests:

1. Navigate to **Security** > **WAF** > **Rate limiting rules**.
2. Click **Create rule**.
3. Configure the following rules:

### Rule 1: Admin Login & OTP Rate Limiter
* **Rule Name:** `Protect Admin Login & OTP`
* **When incoming requests match:**
  * `URI Path` equals `/` **OR** `URI Path` equals `/verify-otp`
* **Rate Limits:**
  * Threshold: **10 requests**
  * Period: **1 minute**
* **Action:** **Block** (or **Managed Challenge**)
* **Duration:** **10 minutes**

---

## 4. Cloudflare Turnstile Configuration (Free CAPTCHA Alternative)

Cloudflare Turnstile delivers frictionless, privacy-preserving bot detection without annoying image puzzles.

1. Navigate to **Turnstile** in the Cloudflare Dashboard sidebar.
2. Click **Add Widget**.
   * **Widget Name:** `CLARO Admin Login`
   * **Domain:** Enter your production domain (e.g., `admin.claro-app.com`) and `localhost` for testing.
   * **Widget Mode:** `Managed` (Cloudflare automatically decides when an interactive check is needed).
3. Copy the generated **Site Key** and **Secret Key**.
4. In your `.env` file (or Render Environment Variables), add:
   ```env
   VITE_CLOUDFLARE_TURNSTILE_SITE_KEY="your-turnstile-site-key-here"
   ```
5. If the site key is omitted during development, the application automatically enables **Dev Bypass Mode** with a green shield indicator so local offline testing remains uninterrupted.

---

## 5. SSL/TLS & Security Headers

1. Navigate to **SSL/TLS** > **Overview**:
   * Set encryption mode to **Full (Strict)**.
2. Under **SSL/TLS** > **Edge Certificates**:
   * Enable **Always Use HTTPS**.
   * Enable **HTTP Strict Transport Security (HSTS)** with max-age of at least 6 months.
   * Set Minimum TLS Version to **TLS 1.2** or **TLS 1.3**.

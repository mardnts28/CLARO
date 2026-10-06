# CLARO Gemini Proxy

Cloudflare Worker that proxies requests to Google's Gemini API and EmailJS, keeping API keys server-side.

## Security Features

### CORS Configuration

This Worker implements configurable CORS (Cross-Origin Resource Sharing) to prevent unauthorized access.

#### Important: Native Mobile Apps

**Native mobile apps (Flutter, iOS, Android) don't have CORS restrictions** because they don't run in a browser environment. They don't send an `Origin` header, so the Worker automatically allows them with wildcard CORS.

**This means**: When you configure `CORS_ALLOWED_ORIGINS` for production, your mobile app will continue to work regardless of the CORS configuration.

#### Configuration Options

**Development Mode (Wildcard - Not Recommended for Production)**
```bash
# Leave CORS_ALLOWED_ORIGINS empty in wrangler.jsonc or environment
CORS_ALLOWED_ORIGINS=""
```

**Production Mode (Restricted Origins - Recommended)**
```bash
# Set specific allowed origins via wrangler secret
npx wrangler secret put CORS_ALLOWED_ORIGINS
# Enter: https://claro-admin.onrender.com
```

#### How to Configure

1. **For Local Development**:
   - Set `CORS_ALLOWED_ORIGINS` in `.env` file:
     ```
     CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173
     ```
   - Or leave empty for wildcard (easier for testing)

2. **For Production Deployment**:
   - Use wrangler secret (recommended):
     ```bash
     npx wrangler secret put CORS_ALLOWED_ORIGINS
     ```
   - Enter your production domains as comma-separated values:
     ```
     https://claro-admin.onrender.com
     ```
   - **Mobile apps will continue to work** (they don't send Origin header)

3. **For Multiple Environments**:
   You can use environment-specific configurations in `wrangler.jsonc`:
   ```json
   "env": {
     "production": {
       "vars": {
         "CORS_ALLOWED_ORIGINS": "https://claro-admin.onrender.com"
       }
     },
     "staging": {
       "vars": {
         "CORS_ALLOWED_ORIGINS": "https://staging.claro-app.com"
       }
     }
   }
   ```

#### Security Note

- **Wildcard CORS (`*`)**: Any website can make requests to this Worker if they have the APP_SHARED_SECRET
- **Restricted CORS**: Only specified domains can make requests from web browsers, even with the correct secret
- **Mobile Apps**: Always allowed (don't send Origin header, so bypass CORS checks)
- **Best Practice**: Always use restricted origins in production to protect web access

### Authentication

All requests must include the `X-App-Secret` header with the correct `APP_SHARED_SECRET` value.

## Deployment

```bash
# Install dependencies
npm install

# Deploy to Cloudflare
npx wrangler deploy

# Set secrets
npx wrangler secret put GEMINI_API_KEY
npx wrangler secret put APP_SHARED_SECRET
npx wrangler secret put EMAILJS_SERVICE_ID
npx wrangler secret put EMAILJS_TEMPLATE_ID
npx wrangler secret put EMAILJS_PUBLIC_KEY
npx wrangler secret put EMAILJS_PRIVATE_KEY
npx wrangler secret put CORS_ALLOWED_ORIGINS  # For production
```

## Endpoints

### POST /email
Sends emails via EmailJS with server-side credentials.

### POST / (default)
Proxies requests to Google's Gemini API with retry logic for geographic restrictions.

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| GEMINI_API_KEY | Google Gemini API key | Yes |
| APP_SHARED_SECRET | Shared secret for app authentication | Yes |
| EMAILJS_SERVICE_ID | EmailJS service ID | Yes |
| EMAILJS_TEMPLATE_ID | EmailJS template ID (for OTP emails) | Yes |
| EMAILJS_CONTACT_TEMPLATE_ID | EmailJS template ID (for contact form) | No (optional) |
| EMAILJS_PUBLIC_KEY | EmailJS public key | Yes |
| EMAILJS_PRIVATE_KEY | EmailJS private key | Yes |
| CORS_ALLOWED_ORIGINS | Comma-separated allowed origins | No (defaults to wildcard) |

### Email Templates

The Worker supports two types of emails:

1. **OTP Emails** (for mobile app MFA):
   - Uses `EMAILJS_TEMPLATE_ID`
   - Expects template variables: `to_email`, `passcode`, `time`

2. **Contact Form Emails** (for official website):
   - Uses `EMAILJS_CONTACT_TEMPLATE_ID` (if set)
   - Falls back to `EMAILJS_TEMPLATE_ID` if not set
   - Expects template variables: `to_email`, `from_name`, `from_email`, `message`

**Note**: If you want the contact form to use a different EmailJS template than OTP emails, create a separate template in EmailJS and set `EMAILJS_CONTACT_TEMPLATE_ID` as a secret.

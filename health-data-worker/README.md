# Health Data Worker

Cloudflare Worker that handles encryption and decryption of sensitive health data (conditions and allergens) using AES-GCM encryption.

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
     CORS_ALLOWED_ORIGINS=http://localhost:3000
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

#### Security Note

- **Wildcard CORS (`*`)**: Any website can make requests to this Worker if they have a valid Firebase ID token
- **Restricted CORS**: Only specified domains can make requests from web browsers, even with valid tokens
- **Mobile Apps**: Always allowed (don't send Origin header, so bypass CORS checks)
- **Best Practice**: Always use restricted origins in production to protect web access

### Authentication

All requests must include a valid Firebase ID token in the `Authorization` header:
```
Authorization: Bearer <firebase-id-token>
```

The Worker verifies the token before allowing access to encrypted health data.

### Encryption

- **Algorithm**: AES-GCM (Galois/Counter Mode)
- **Key Size**: 256-bit
- **IV Size**: 12 bytes (96 bits)
- **Authentication**: Built-in authentication tag ensures data integrity

## Endpoints

### GET /health-profile
Decrypts and returns the user's health conditions and allergens.

**Headers**:
- `Authorization: Bearer <firebase-id-token>`

**Response**:
```json
{
  "conditions": ["diabetes", "hypertension"],
  "allergens": ["peanuts", "shellfish"]
}
```

### POST /health-profile
Encrypts and updates the user's health conditions and allergens.

**Headers**:
- `Authorization: Bearer <firebase-id-token>`
- `Content-Type: application/json`

**Body**:
```json
{
  "conditions": ["diabetes", "hypertension"],
  "allergens": ["peanuts", "shellfish"]
}
```

**Response**:
```json
{
  "success": true
}
```

### GET /group-member-health-profile
Decrypts and returns a group member's health profile (for group owners).

**Headers**:
- `Authorization: Bearer <firebase-id-token>`

**Query Parameters**:
- `groupId`: The group ID
- `memberId`: The member ID

**Response**:
```json
{
  "conditions": ["diabetes"],
  "allergens": ["peanuts"]
}
```

### POST /group-member-health-profile
Encrypts and updates a group member's health profile (for group owners).

**Headers**:
- `Authorization: Bearer <firebase-id-token>`
- `Content-Type: application/json`

**Body**:
```json
{
  "groupId": "group-123",
  "memberId": "member-456",
  "conditions": ["diabetes"],
  "allergens": ["peanuts"]
}
```

**Response**:
```json
{
  "success": true
}
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| HEALTH_ENCRYPTION_KEY | AES-256 encryption key (base64-encoded) | Yes |
| GCP_CLIENT_EMAIL | Google Cloud service account email | Yes |
| GCP_PRIVATE_KEY | Google Cloud service account private key | Yes |
| FIREBASE_PROJECT_ID | Firebase project ID | Yes |
| CORS_ALLOWED_ORIGINS | Comma-separated allowed origins | No (defaults to wildcard) |

## Deployment

```bash
# Install dependencies
npm install

# Deploy to Cloudflare
npx wrangler deploy

# Set secrets
npx wrangler secret put HEALTH_ENCRYPTION_KEY
npx wrangler secret put GCP_CLIENT_EMAIL
npx wrangler secret put GCP_PRIVATE_KEY
npx wrangler secret put FIREBASE_PROJECT_ID
npx wrangler secret put CORS_ALLOWED_ORIGINS  # For production
```

## Security Notes

1. **Firebase ID Token Verification**: Every request must include a valid Firebase ID token. The Worker verifies the token before processing.

2. **AES-GCM Encryption**: Health data is encrypted with AES-GCM, which provides both confidentiality and integrity. The authentication tag ensures any tampering is detected.

3. **Owner-Only Access**: The Worker enforces that users can only access their own health data. Group owners can access managed members' data.

4. **CORS Protection**: Web browser requests are restricted to allowed origins. Native mobile apps bypass CORS checks.

5. **Key Security**: The encryption key is stored as a Cloudflare Worker secret and never exposed to client applications.

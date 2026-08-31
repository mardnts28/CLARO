# CLARO Admin Dashboard

React + Vite admin dashboard for managing CLARO food scanning application reports, reviews, and administrative functions.

## 🚀 Getting Started

### Prerequisites
- Node.js 18+ 
- npm or yarn
- Firebase project with Firestore and Authentication enabled
- EmailJS account for OTP functionality

### Local Development Setup

1. **Clone the repository and navigate to the admin directory:**
   ```bash
   cd admin-claro
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Set up environment variables:**
   - Copy `.env.example` to `.env`:
     ```bash
     cp .env.example .env
     ```
   - Fill in your Firebase and EmailJS credentials in `.env`

4. **Start the development server:**
   ```bash
   npm run dev
   ```

5. **Open your browser:**
   Navigate to `http://localhost:3000`

## 🔐 Environment Variables

The application requires the following environment variables to be set in `.env`:

### Firebase Configuration
- `VITE_FIREBASE_API_KEY` - Your Firebase API key
- `VITE_FIREBASE_AUTH_DOMAIN` - Firebase auth domain (e.g., `your-project.firebaseapp.com`)
- `VITE_FIREBASE_PROJECT_ID` - Your Firebase project ID
- `VITE_FIREBASE_STORAGE_BUCKET` - Firebase storage bucket (e.g., `your-project.firebasestorage.app`)
- `VITE_FIREBASE_MESSAGING_SENDER_ID` - Firebase messaging sender ID
- `VITE_FIREBASE_APP_ID` - Firebase app ID
- `VITE_FIREBASE_MEASUREMENT_ID` - Firebase measurement ID (optional)

### EmailJS Configuration
- `VITE_EMAILJS_SERVICE_ID` - EmailJS service ID
- `VITE_EMAILJS_TEMPLATE_ID` - EmailJS template ID for OTP emails
- `VITE_EMAILJS_PUBLIC_KEY` - EmailJS public key

### Admin Scripts (Optional)
- `SERVICE_ACCOUNT_PATH` - Path to Firebase service account JSON for admin scripts (default: `./serviceAccountKey.json`)

## 🌐 Deployment

### Render Deployment

The application is configured for deployment on Render using the provided `render.yaml` file.

#### Prerequisites
1. Push your code to a Git repository (GitHub, GitLab, etc.)
2. Create a Render account at [render.com](https://render.com)
3. Have your Firebase and EmailJS credentials ready

#### Deployment Steps

1. **Connect your repository to Render:**
   - In Render dashboard, click "New +"
   - Select "Web Service"
   - Connect your Git repository
   - Select the `admin-claro` directory as the root directory

2. **Configure the service:**
   - Name: `claro-admin` (or your preferred name)
   - Runtime: Static
   - Build Command: `npm run build`
   - Publish Directory: `./dist`

3. **Set environment variables in Render:**
   In the Render dashboard, add the following environment variables:
   ```
   VITE_FIREBASE_API_KEY=your_actual_api_key
   VITE_FIREBASE_AUTH_DOMAIN=your_project.firebaseapp.com
   VITE_FIREBASE_PROJECT_ID=your_project_id
   VITE_FIREBASE_STORAGE_BUCKET=your_project.firebasestorage.app
   VITE_FIREBASE_MESSAGING_SENDER_ID=your_messaging_sender_id
   VITE_FIREBASE_APP_ID=your_app_id
   VITE_FIREBASE_MEASUREMENT_ID=your_measurement_id
   VITE_EMAILJS_SERVICE_ID=your_emailjs_service_id
   VITE_EMAILJS_TEMPLATE_ID=your_emailjs_template_id
   VITE_EMAILJS_PUBLIC_KEY=your_emailjs_public_key
   ```

4. **Deploy:**
   - Click "Create Web Service"
   - Render will automatically build and deploy your application
   - The deployment URL will be provided once complete

5. **Configure custom domain (optional):**
   - In Render dashboard, go to your service settings
   - Add your custom domain
   - Update DNS settings as instructed by Render

#### Automatic Deployments
The `render.yaml` file is configured to automatically deploy when you push to the `merged-works` branch.

### Manual Deployment

For manual deployment to other platforms:

1. **Build the application:**
   ```bash
   npm run build
   ```

2. **The built files will be in the `dist/` directory**
   - Upload the contents of `dist/` to your hosting service
   - Ensure your hosting service supports single-page applications (SPA)

3. **Configure environment variables on your platform**
   - Set the same environment variables as listed above
   - Platform-specific configuration may be required

## 🧪 Testing

### Running Tests
```bash
npm run lint
```

### Building for Production
```bash
npm run build
```

### Preview Production Build
```bash
npm run build
npm run preview
```

## 📝 Admin Scripts

### Backfill Admin Names
Script to backfill admin names in activity logs:
```bash
npm run migrate:backfill-admin-names
```

Requires a Firebase service account JSON file. Set the `SERVICE_ACCOUNT_PATH` environment variable or place the file at `./serviceAccountKey.json`.

## 🔧 Troubleshooting

### Build Issues
- **Missing environment variables:** Ensure all required variables are set in `.env` for local development or in Render dashboard for production
- **Module not found:** Run `npm install` to ensure all dependencies are installed
- **Firebase connection issues:** Verify your Firebase configuration and that your Firebase project is properly set up

### Deployment Issues
- **Build fails on Render:** Check the deployment logs in Render dashboard for specific error messages
- **Environment variables not working:** Ensure variables are prefixed with `VITE_` for client-side access
- **Static file serving:** Ensure your hosting service is configured for SPA routing (all routes should serve index.html)

### Development Issues
- **Port already in use:** The dev server uses port 3000 by default. You can change this in `vite.config.js`
- **Hot module replacement not working:** Try stopping and restarting the dev server
- **Firebase authentication issues:** Verify your Firebase Auth configuration and that your domain is authorized in Firebase console

## 🔒 Security Notes

- **Never commit `.env` file** to version control - it's already in `.gitignore`
- **Use different API keys** for development and production environments
- **Rotate credentials** if they are ever accidentally exposed
- **Enable Firebase Security Rules** to protect your Firestore database
- **Regularly audit** your Firebase project for unauthorized access

## 📚 Additional Resources

- [Vite Documentation](https://vite.dev/)
- [React Documentation](https://react.dev/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [EmailJS Documentation](https://www.emailjs.com/docs/)
- [Render Documentation](https://render.com/docs)

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the Oxlint configuration

If you are developing a production application, we recommend using TypeScript with type-aware lint rules enabled. Check out the [TS template](https://github.com/vitejs/vite/tree/main/packages/create-vite/template-react-ts) for information on how to integrate TypeScript and Oxlint's TypeScript related rules in your application.
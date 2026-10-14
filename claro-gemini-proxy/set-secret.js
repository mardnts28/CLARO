const fs = require('fs');
const { execSync } = require('child_process');

// Read the service account JSON file
const serviceAccountPath = process.argv[2];
if (!serviceAccountPath) {
  console.error('Please provide the path to your service account JSON file');
  process.exit(1);
}

const serviceAccountJson = fs.readFileSync(serviceAccountPath, 'utf8');
const escapedJson = JSON.stringify(serviceAccountJson);

console.log('Setting FIREBASE_SERVICE_ACCOUNT_JSON secret...');
try {
  execSync(`echo "${escapedJson}" | wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON`, {
    stdio: 'inherit',
    cwd: __dirname
  });
  console.log('Secret set successfully!');
} catch (error) {
  console.error('Failed to set secret:', error.message);
  process.exit(1);
}

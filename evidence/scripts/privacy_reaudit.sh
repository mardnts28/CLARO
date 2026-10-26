#!/usr/bin/env bash
# privacy_reaudit.sh - Scans evidence and git history for sensitive keys, tokens, and private infrastructure.
# Standard baseline: Developer-side technical evaluation privacy safeguard.

set -euo pipefail

echo "=== A7. EVIDENCE PRIVACY RE-AUDIT ==="

echo -e "\n--- 1. Working Directory evidence/ Scan ---"
echo -n "Google API Key (AIza...)      : "; (grep -rnE 'AIza[0-9A-Za-z-_]{35}' evidence/ 2>/dev/null || true) | wc -l | tr -d ' ' | sed 's/$/ matches/'
echo -n "JWT Token (eyJ...)            : "; (grep -rnE 'eyJ[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.?[A-Za-z0-9-_.+/=]*' evidence/ 2>/dev/null || true) | wc -l | tr -d ' ' | sed 's/$/ matches/'
echo -n "Bearer Token                  : "; (grep -rnE 'bearer [a-zA-Z0-9_.-]+' evidence/ 2>/dev/null || true) | wc -l | tr -d ' ' | sed 's/$/ matches/'
echo -n "Password references           : "; (grep -inE 'password\s*[:=]\s*["'\''][^"'\'']+["'\'']' evidence/ 2>/dev/null || true) | wc -l | tr -d ' ' | sed 's/$/ matches/'
echo -n "Secret references             : "; (grep -inE 'secret\s*[:=]\s*["'\''][^"'\'']+["'\'']' evidence/ 2>/dev/null || true) | wc -l | tr -d ' ' | sed 's/$/ matches/'
echo -n "Token parameter (token=)      : "; (grep -inE 'token=[a-zA-Z0-9_-]{10,}' evidence/ 2>/dev/null || true) | wc -l | tr -d ' ' | sed 's/$/ matches/'
echo -n "API Key parameter (apikey=)   : "; (grep -inE 'apikey=[a-zA-Z0-9_-]{10,}' evidence/ 2>/dev/null || true) | wc -l | tr -d ' ' | sed 's/$/ matches/'
echo -n "Workers.dev hostnames         : "; (grep -rnE '[a-zA-Z0-9_-]+\.workers\.dev' evidence/ 2>/dev/null || true) | wc -l | tr -d ' ' | sed 's/$/ matches/'
echo -n "Cloudinary cloud names        : "; (grep -rnE 'api\.cloudinary\.com/v1_1/[a-zA-Z0-9_-]+' evidence/ 2>/dev/null || true) | wc -l | tr -d ' ' | sed 's/$/ matches/'
echo -n "Firebase project IDs          : "; (grep -rnE '[a-z0-9-]+\.firebaseio\.com' evidence/ 2>/dev/null || true) | wc -l | tr -d ' ' | sed 's/$/ matches/'
echo -n "Email addresses               : "; (grep -rnE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' evidence/ 2>/dev/null || true) | wc -l | tr -d ' ' | sed 's/$/ matches/'

echo -e "\n--- 2. Git History of evidence/ Scan ---"
echo -n "Google API Key (AIza...)      : "; (git log -p -- evidence/ | grep -E '^\+[^+]' | grep -E 'AIza[0-9A-Za-z-_]{35}' || true) | wc -l | tr -d ' ' | sed 's/$/ matches in git log/'
echo -n "JWT Token (eyJ...)            : "; (git log -p -- evidence/ | grep -E '^\+[^+]' | grep -E 'eyJ[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.?[A-Za-z0-9-_.+/=]*' || true) | wc -l | tr -d ' ' | sed 's/$/ matches in git log/'
echo -n "Bearer Token                  : "; (git log -p -- evidence/ | grep -E '^\+[^+]' | grep -E 'bearer [a-zA-Z0-9_.-]+' || true) | wc -l | tr -d ' ' | sed 's/$/ matches in git log/'
echo -n "Password references           : "; (git log -p -- evidence/ | grep -E '^\+[^+]' | grep -iE 'password\s*[:=]\s*["'\''][^"'\'']+["'\'']' || true) | wc -l | tr -d ' ' | sed 's/$/ matches in git log/'
echo -n "Secret references             : "; (git log -p -- evidence/ | grep -E '^\+[^+]' | grep -iE 'secret\s*[:=]\s*["'\''][^"'\'']+["'\'']' || true) | wc -l | tr -d ' ' | sed 's/$/ matches in git log/'
echo -n "Token parameter (token=)      : "; (git log -p -- evidence/ | grep -E '^\+[^+]' | grep -iE 'token=[a-zA-Z0-9_-]{10,}' || true) | wc -l | tr -d ' ' | sed 's/$/ matches in git log/'
echo -n "API Key parameter (apikey=)   : "; (git log -p -- evidence/ | grep -E '^\+[^+]' | grep -iE 'apikey=[a-zA-Z0-9_-]{10,}' || true) | wc -l | tr -d ' ' | sed 's/$/ matches in git log/'
echo -n "Workers.dev hostnames         : "; (git log -p -- evidence/ | grep -E '^\+[^+]' | grep -E '[a-zA-Z0-9_-]+\.workers\.dev' || true) | wc -l | tr -d ' ' | sed 's/$/ matches in git log/'
echo -n "Cloudinary cloud names        : "; (git log -p -- evidence/ | grep -E '^\+[^+]' | grep -E 'api\.cloudinary\.com/v1_1/[a-zA-Z0-9_-]+' || true) | wc -l | tr -d ' ' | sed 's/$/ matches in git log/'
echo -n "Firebase project IDs          : "; (git log -p -- evidence/ | grep -E '^\+[^+]' | grep -E '[a-z0-9-]+\.firebaseio\.com' || true) | wc -l | tr -d ' ' | sed 's/$/ matches in git log/'
echo -n "Email addresses               : "; (git log -p -- evidence/ | grep -E '^\+[^+]' | grep -E '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' || true) | wc -l | tr -d ' ' | sed 's/$/ matches in git log/'

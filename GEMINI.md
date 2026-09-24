# CLARO - Antigravity Agent Configuration & Project Guide

## Overview
CLARO is a Flutter mobile application designed for healthcare/accessibility tracking and assistance. It integrates Firebase services (Authentication, Firestore, Cloud Functions), on-device machine learning (TFLite), audio/speech capabilities, and camera scanning.

## Tech Stack & Environment
- **Framework:** Flutter (>=3.12.0 Dart SDK)
- **State Management:** Provider
- **Backend & Cloud:** Firebase Core, Firebase Auth, Cloud Firestore, Cloud Functions
- **Hardware / Device Plugins:**
  - Camera (`camera`)
  - QR / Barcode Scanner (`mobile_scanner`, `qr_flutter`)
  - Speech & Audio (`speech_to_text`, `flutter_tts`)
  - Machine Learning (`tflite_flutter`)
  - Local Storage (`shared_preferences`)
  - Encryption (`encrypt`, `crypto`)

## Project Architecture & Directory Structure
```
c:\Users\Joy\AndroidStudioProjects\main\
├── lib/
│   ├── core/         # Core utilities, constants, theme, localization
│   ├── data/         # Data providers, repositories, local storage
│   ├── models/       # Data models and serializable entities
│   ├── screens/      # Screen-level widgets and views (UI flow)
│   ├── services/     # Firebase, API, TFLite, TTS/STT services
│   ├── widgets/      # Reusable UI components
│   ├── firebase_options.dart
│   └── main.dart     # Application entrypoint
├── test/             # Unit and widget test suite
├── integration_test/ # Integration tests
├── android/          # Android platform native code and Gradle configurations
├── ios/              # iOS platform configuration
├── assets/           # Images, models, and UI assets
└── firestore.rules   # Cloud Firestore security rules
```

## Common Developer Commands
- **Install dependencies:** `flutter pub get`
- **Run static analysis:** `flutter analyze`
- **Run tests:** `flutter test`
- **Build Android debug APK:** `flutter build apk --debug`
- **Check git status:** `git status`
- **Sync with remote:** `git pull origin main` / `git push origin main`

## Agent Guidelines & Best Practices
1. **State Management:** Use `Provider` for state management consistency across screens and widgets.
2. **Type Safety & Null Safety:** Strictly follow modern Dart null-safety patterns. Avoid unnecessary `!` bang operators.
3. **Firebase & Security:** Ensure Firestore security rules in `firestore.rules` mirror backend security assumptions. Never commit production API keys or credentials directly into code.
4. **Code Quality:** Before proposing major refactors, ensure tests pass via `flutter test` and check for warnings using `flutter analyze`.
5. **Localization & Accessibility:** Maintain UI accessibility and support internationalization patterns using `flutter_localizations` and `intl`.

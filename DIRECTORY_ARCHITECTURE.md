# Project Directory Architecture

claro/
├── android/                  # Android-specific project files
├── assets/                   # Static assets such as images
├── build/                    # Build outputs and generated files
├── ios/                      # iOS-specific project files
├── lib/                      # Main application source code
│   ├── main.dart             # App entry point
│   └── screens/              # App screens
│       ├── login_screen.dart
│       ├── onboarding_screen.dart
│       └── signup_screen.dart
├── linux/                    # Linux desktop support files
├── macos/                    # macOS desktop support files
├── test/                     # Tests
├── web/                      # Web app files
├── windows/                  # Windows desktop support files
├── analysis_options.yaml     # Linting and analyzer settings
├── claro.iml                 # IntelliJ/Android Studio project file
├── pubspec.yaml              # Flutter dependencies and metadata
└── README.md                 # Project documentation

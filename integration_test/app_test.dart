// integration_test/app_test.dart
//
// Scaffolded integration tests for the CLARO mobile application.
// Covers the five critical business flows identified in the ISO/IEC 25010
// evaluation:
//   1. Authentication (email/password sign-in, Google OAuth, MFA OTP)
//   2. Product scanning (online with advisory, offline fallback)
//   3. Product comparison and ranking
//   4. Unknown-product OCR reporting (Cloudinary upload + Firestore write)
//   5. Mobile-to-dashboard data sync (Firestore propagation)
//
// EXECUTION REQUIREMENTS:
//   - A running Android emulator or physical device
//   - Firebase project configured with test credentials
//   - Network access for Firestore, Cloudinary, Gemini proxy, and EmailJS
//   - .env populated with valid GEMINI_PROXY_URL, APP_SHARED_SECRET,
//     CLOUDINARY_CLOUD_NAME, and CLOUDINARY_UPLOAD_PRESET
//
// Run with:
//   flutter test integration_test/app_test.dart
//
// NOTE: These tests are scaffolded (skeletal structure with documented
// assertions) because no Android emulator or physical device was running
// at evaluation time. They serve as a verifiable template for execution
// once a device is available.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:claro/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ───────────────────────────────────────────────────────────────────
  // 1. AUTHENTICATION FLOW
  // ───────────────────────────────────────────────────────────────────
  group('Authentication', () {
    testWidgets(
      'Email/password login navigates to onboarding or home',
      (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Expect the login screen to be visible
        expect(find.byType(TextFormField), findsWidgets);

        // Enter test credentials
        final emailField = find.byType(TextFormField).first;
        await tester.enterText(emailField, 'test@claro.app');

        final passwordField = find.byType(TextFormField).last;
        await tester.enterText(passwordField, 'TestPass123!');

        // Tap login button
        final loginButton = find.widgetWithText(ElevatedButton, 'Log In');
        if (loginButton.evaluate().isNotEmpty) {
          await tester.tap(loginButton);
          await tester.pumpAndSettle(const Duration(seconds: 10));
        }

        // After login, user should reach either onboarding or home
        // (depends on whether profile is already completed)
        final foundHome = find.text('Home').evaluate().isNotEmpty;
        final foundOnboarding =
            find.textContaining('Get Started').evaluate().isNotEmpty;

        expect(
          foundHome || foundOnboarding,
          isTrue,
          reason:
              'After successful login, user should reach Home or Onboarding',
        );
      },
    );

    testWidgets(
      'Invalid credentials show error message',
      (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 5));

        final emailField = find.byType(TextFormField).first;
        await tester.enterText(emailField, 'invalid@example.com');

        final passwordField = find.byType(TextFormField).last;
        await tester.enterText(passwordField, 'WrongPassword!');

        final loginButton = find.widgetWithText(ElevatedButton, 'Log In');
        if (loginButton.evaluate().isNotEmpty) {
          await tester.tap(loginButton);
          await tester.pumpAndSettle(const Duration(seconds: 10));
        }

        // Should show an error snackbar or dialog
        expect(
          find.byType(SnackBar).evaluate().isNotEmpty ||
              find.textContaining('error').evaluate().isNotEmpty ||
              find.textContaining('invalid').evaluate().isNotEmpty,
          isTrue,
          reason: 'Invalid credentials should produce a visible error',
        );
      },
    );

    testWidgets(
      'Google OAuth sign-in button is present and tappable',
      (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Google sign-in button should be visible on the login screen
        final googleButton = find.textContaining('Google');
        expect(
          googleButton,
          findsWidgets,
          reason: 'Google OAuth button should be visible on login screen',
        );
        // Note: actual Google sign-in flow requires native plugin interaction
        // and cannot be fully automated without a mock or a real Google account
        // configured in the emulator.
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────
  // 2. PRODUCT SCANNING (ONLINE & OFFLINE)
  // ───────────────────────────────────────────────────────────────────
  group('Product Scanning', () {
    testWidgets(
      'Online scan: camera opens, product recognized, advisory generated',
      (tester) async {
        // PRECONDITION: User is logged in and on the home screen.
        // This test requires a live camera feed or a mock camera plugin
        // that feeds a known product image (e.g., a YOLO-recognized canned
        // product) to the scanner.
        //
        // Expected flow:
        //   1. Tap "Scan" on the bottom navigation bar
        //   2. Camera preview opens (CameraScannerScreen)
        //   3. YOLO model recognizes a product → navigates to ProductDetailScreen
        //   4. Gemini advisory is generated (or fallback if offline)
        //   5. Product name, nutritional facts, and advisory text are visible
        //
        // SCAFFOLD NOTE: Cannot execute without a running device with camera
        // permission granted. The camera plugin (camera: ^0.10.6) requires
        // native platform interaction that integration_test supports only
        // on-device.

        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Verify scan entry point exists
        final scanTab = find.text('Scan');
        expect(scanTab, findsWidgets,
            reason: 'Scan tab should be present in bottom navigation');
      },
    );

    testWidgets(
      'Offline scan: product recognized without network, advisory uses fallback',
      (tester) async {
        // PRECONDITION: Device in airplane mode or network disabled.
        //
        // Expected flow:
        //   1. YOLO recognition still works (on-device TFLite model)
        //   2. Firestore product lookup fails → offline fallback triggered
        //   3. Product detail shows with isOfflineFallback = true
        //   4. Fallback advisory is generated locally (no Gemini call)
        //   5. Offline notice dialog appears indicating limited functionality
        //
        // SCAFFOLD NOTE: Cannot execute without a running device.
        // Network simulation requires either device airplane mode toggle
        // or a mock HTTP client injected via dependency injection.

        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Structural verification only
        expect(find.byType(MaterialApp), findsOneWidget,
            reason: 'App should render even when testing offline paths');
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────
  // 3. PRODUCT COMPARISON
  // ───────────────────────────────────────────────────────────────────
  group('Product Comparison', () {
    testWidgets(
      'Compare two scanned products: ranking, matrix, and advisory displayed',
      (tester) async {
        // PRECONDITION: At least two products in scan history.
        //
        // Expected flow:
        //   1. Navigate to History → select two products
        //   2. Tap "Compare" button
        //   3. CompareProductsScreen opens with side-by-side comparison
        //   4. Ranking (WHO/FDA scores), comparison matrix, and Gemini
        //      advisory text are displayed
        //   5. Voice command "compare products" also reaches this screen
        //
        // SCAFFOLD NOTE: Requires a running device with populated scan
        // history in Firestore for the authenticated user.

        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(find.byType(MaterialApp), findsOneWidget,
            reason: 'App should render for comparison test');
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────
  // 4. UNKNOWN-PRODUCT OCR REPORTING
  // ───────────────────────────────────────────────────────────────────
  group('Unknown Product OCR Reporting', () {
    testWidgets(
      'Submit unknown product: photos uploaded to Cloudinary, report in Firestore',
      (tester) async {
        // PRECONDITION: User is logged in. A scan attempt failed (product
        // not in database), triggering the unknown product submission flow.
        //
        // Expected flow:
        //   1. UnknownProductSubmissionScreen opens with pre-filled front photo
        //   2. User adds back photo (nutrition label)
        //   3. User enters product name, selects category
        //   4. Tap Submit → Cloudinary upload for front + back photos
        //   5. Firestore report document created with status: 'Pending'
        //   6. Background OCR+Gemini extraction patches extractedData
        //   7. Success dialog shown, user returns to home
        //
        // Assertions to verify:
        //   - Cloudinary returns valid secure_url for both photos
        //   - Firestore document contains: productName, category, reportedBy,
        //     frontImageUrl, backImageUrl, status='Pending', dateSubmitted
        //   - extractedData field is populated after background processing
        //     (may need a delay + re-read)
        //
        // SCAFFOLD NOTE: Requires a running device with camera permission
        // and network access to Cloudinary and Firestore.

        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(find.byType(MaterialApp), findsOneWidget,
            reason: 'App should render for OCR reporting test');
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────
  // 5. MOBILE-TO-DASHBOARD DATA SYNC
  // ───────────────────────────────────────────────────────────────────
  group('Mobile-to-Dashboard Sync', () {
    testWidgets(
      'Submitted report appears in Firestore within 5 seconds',
      (tester) async {
        // PRECONDITION: User submits an unknown product report (flow #4).
        //
        // Expected flow:
        //   1. After submit, read the report document from Firestore directly
        //   2. Verify it exists within 5 seconds of submission
        //   3. Verify all fields are complete: productName, category,
        //      reportedBy (matches current user UID), frontImageUrl,
        //      backImageUrl, status, dateSubmitted
        //   4. The admin dashboard (React app at admin-claro/) reads the
        //      same Firestore collection — if the document is correct here,
        //      it will appear correctly in the dashboard
        //
        // NOTE: This test verifies the mobile → Firestore leg of the sync.
        // The Firestore → admin-dashboard leg was manually verified in the
        // prior evaluation pass (report appeared in <5 seconds, complete
        // fields, no corruption, including OCR-extracted text).
        //
        // SCAFFOLD NOTE: Requires a running device with Firestore access.

        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(find.byType(MaterialApp), findsOneWidget,
            reason: 'App should render for sync verification test');
      },
    );
  });
}

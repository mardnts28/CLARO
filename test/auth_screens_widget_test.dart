import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claro/generated/l10n/app_localizations.dart';
import 'package:claro/screens/forgot_password_screen.dart';
import 'package:claro/services/validation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    );
  }

  group('ForgotPasswordScreen Widget & Validation Tests', () {
    testWidgets('renders reset password screen with title and input field',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);
      expect(
        find.text(
            'Enter your email address and we will send you a link to reset your password.'),
        findsOneWidget,
      );
      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('shows validation error when email is submitted empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      final sendButton = find.text('Send Reset Link');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('shows validation error when email format is invalid',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      final emailField = find.byType(TextField);
      expect(emailField, findsOneWidget);

      await tester.enterText(emailField, 'notanemail');
      await tester.pumpAndSettle();

      final sendButton = find.text('Send Reset Link');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });
  });

  group('ValidationService Auth Unit Tests', () {
    test('validateEmail returns proper errors in English and Tagalog', () {
      final locEn = lookupAppLocalizations(const Locale('en'));
      final locTl = lookupAppLocalizations(const Locale('tl'));

      expect(ValidationService.validateEmail('', locEn), equals('Email is required'));
      expect(ValidationService.validateEmail('invalid', locEn),
          equals('Please enter a valid email address'));
      expect(ValidationService.validateEmail('test@claro.com', locEn), isNull);

      expect(ValidationService.validateEmail('', locTl), equals('Kinakailangan ang email'));
      expect(ValidationService.validateEmail('test@claro.com', locTl), isNull);
    });

    test('validatePassword enforces length and complexity rules', () {
      final locEn = lookupAppLocalizations(const Locale('en'));

      expect(ValidationService.validatePassword('', locEn), equals('Password is required'));
      expect(ValidationService.validatePassword('short', locEn),
          equals('Password must be at least 8 characters'));
      expect(ValidationService.validatePassword('alllowercase123', locEn),
          equals('Password must contain at least one uppercase letter'));
      expect(ValidationService.validatePassword('ALLUPPERCASE123', locEn),
          equals('Password must contain at least one lowercase letter'));
      expect(ValidationService.validatePassword('NoNumbersHere!', locEn),
          equals('Password must contain at least one number'));
      expect(ValidationService.validatePassword('ValidPass123!', locEn), isNull);
    });
  });
}

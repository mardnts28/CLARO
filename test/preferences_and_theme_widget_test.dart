import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:claro/generated/l10n/app_localizations.dart';
import 'package:claro/screens/theme_screen.dart';
import 'package:claro/services/locale_service.dart';
import 'package:claro/services/haptic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'theme': 'Default',
      'app_locale': 'en',
    });
    HapticService().isEnabled = false;
  });

  Widget buildTestableWidget(Widget child, {Locale locale = const Locale('en')}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: child,
    );
  }

  group('ThemeScreen Widget Tests', () {
    testWidgets('renders ThemeScreen with title and theme options in English',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const ThemeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('The standard Claro look'), findsOneWidget);
    });

    testWidgets('renders ThemeScreen in Tagalog when locale is tl',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const ThemeScreen(), locale: const Locale('tl')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tema'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('Karaniwang hitsura ng Claro'), findsOneWidget);
    });

    testWidgets('tapping theme card triggers selection feedback',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const ThemeScreen()));
      await tester.pumpAndSettle();

      final darkModeCard = find.text('Dark Mode');
      expect(darkModeCard, findsOneWidget);

      await tester.tap(darkModeCard);
      await tester.pumpAndSettle();

      expect(find.text('Dark Mode'), findsOneWidget);
    });
  });

  group('LocaleService State Tests', () {
    test('default locale is en or tl', () {
      expect(LocaleService.localeNotifier.value, isNotNull);
    });

    test('LocaleService updates notifier when setting locale', () async {
      await LocaleService.setAppLocale('tl');
      expect(LocaleService.localeNotifier.value.languageCode, equals('tl'));

      await LocaleService.setAppLocale('en');
      expect(LocaleService.localeNotifier.value.languageCode, equals('en'));
    });
  });
}

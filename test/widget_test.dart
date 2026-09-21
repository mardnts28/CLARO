import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claro/generated/l10n/app_localizations.dart';
import 'package:claro/screens/onboarding_screen.dart';
import 'package:claro/widgets/avatar_picker.dart';

void main() {
  testWidgets('onboarding next button stays disabled until required info is entered', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const OnboardingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final nextButton = find.widgetWithText(ElevatedButton, 'Next');
    expect(nextButton, findsOneWidget);
    expect(tester.widget<ElevatedButton>(nextButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Alicia');
    await tester.pump();

    final avatar = find.descendant(
      of: find.byType(AvatarPicker),
      matching: find.byType(GestureDetector),
    ).first;
    expect(avatar, findsOneWidget);
    expect(tester.widget<ElevatedButton>(nextButton).onPressed, isNull);

    await tester.ensureVisible(avatar);
    await tester.tap(avatar);
    await tester.pump();

    final onboardingState = tester.state(find.byType(OnboardingScreen)) as dynamic;
    expect(onboardingState.isBasicInfoValid(), isTrue);
    expect(tester.widget<ElevatedButton>(nextButton).onPressed, isNotNull);
  });
}

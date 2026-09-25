import 'package:claro/services/guest_favorites_service.dart';
import 'package:claro/services/guest_session.dart';
import 'package:claro/widgets/account_required_gate.dart';
import 'package:claro/widgets/locked_feature_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    GuestSession.clear();
    GuestFavoritesService.clear();
  });

  test('guest session is process-local and clears on conversion', () {
    expect(GuestSession.isGuest.value, isFalse);
    GuestSession.enter();
    expect(GuestSession.isGuest.value, isTrue);
    GuestSession.clear();
    expect(GuestSession.isGuest.value, isFalse);
  });

  test('guest favorites toggle in memory and clear without persistence', () {
    GuestSession.enter();
    expect(GuestFavoritesService.isFavorite('p1'), isFalse);
    expect(GuestFavoritesService.toggle('p1'), isTrue);
    expect(GuestFavoritesService.isFavorite('p1'), isTrue);
    expect(GuestFavoritesService.toggle('p1'), isFalse);
    GuestFavoritesService.toggle('p1');
    GuestFavoritesService.clear();
    expect(GuestFavoritesService.isFavorite('p1'), isFalse);
  });

  testWidgets('locked card exposes accessible personalized-insight prompt', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LockedFeatureCard(
          title: 'Sign in for Personalized Safety Insights',
          subtitle:
              'See if this product is safe for your specific health conditions and allergies.',
          ctaLabel: 'Sign In',
          onCtaPress: () {},
        ),
      ),
    );

    expect(
      find.text('Sign in for Personalized Safety Insights'),
      findsOneWidget,
    );
    expect(find.text('Sign In'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label ==
                'Locked. Sign in required to view personalized health advisory.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('account gate shows the guest conversion prompt', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountRequiredGate(
          message: 'Sign up to save and view your scan history',
          onLogin: () {},
          onCreateAccount: () {},
        ),
      ),
    );

    expect(
      find.text('Sign up to save and view your scan history'),
      findsOneWidget,
    );
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claro/screens/product_detail/serving_selector.dart';
import 'package:claro/screens/product_detail/advisory_banner_widget.dart';
import 'package:claro/screens/product_detail/nutrition_breakdown_card.dart';
import 'package:claro/core/constants/who_fda_thresholds.dart';
import 'package:claro/generated/l10n/app_localizations.dart';

void main() {
  group('Product Detail Sub-Widgets Tests', () {
    testWidgets('ServingSelector renders options and triggers onSizeChanged', (
      tester,
    ) async {
      double? updatedSize;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServingSelector(
              selectedSizeG: 100.0,
              availableSizes: const [100.0, 155.0, 200.0],
              onSizeChanged: (newSize) {
                updatedSize = newSize;
              },
            ),
          ),
        ),
      );

      expect(find.text('100g'), findsOneWidget);

      // Tap dropdown to open menu
      await tester.tap(find.byType(ServingSelector));
      await tester.pumpAndSettle();

      expect(find.text('155g'), findsWidgets);
      await tester.tap(find.text('155g').last);
      await tester.pumpAndSettle();

      expect(updatedSize, 155.0);
    });

    testWidgets('AdvisoryBannerWidget renders banner title and emphasized subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdvisoryBannerWidget(
              level: AdvisoryLevel.caution,
              color: Colors.red,
              icon: Icons.warning_amber_rounded,
              title: 'Caution - High Sodium',
              subtitle:
                  'This product is high in sodium. Limit portion size. Consume at most 1 serving per day.',
            ),
          ),
        ),
      );

      expect(find.text('Caution - High Sodium'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('AdvisoryBannerWidget renders multi-allergen rows when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdvisoryBannerWidget(
              level: AdvisoryLevel.caution,
              color: Colors.red,
              icon: Icons.warning_amber_rounded,
              title: 'Caution - Allergens',
              subtitle: 'Contains allergens.',
              multiAllergenRows: [
                MultiAllergenDisplayRow(
                  allergen: 'Soy',
                  ingredient: 'Soy sauce',
                ),
                MultiAllergenDisplayRow(
                  allergen: 'Wheat',
                  ingredient: 'Wheat flour',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Multiple allergen detected'), findsOneWidget);
      expect(find.textContaining('Soy:'), findsOneWidget);
      expect(find.textContaining('Wheat:'), findsOneWidget);
    });

    testWidgets('NutrientRowWidget renders formatted nutrient facts and indicator', (
      tester,
    ) async {
      final eval = DisplayNutrientEval(
        label: 'Hypertension - Sodium',
        shortLabel: 'Sodium',
        nutrientKey: 'sodiumMg',
        valuePerServing: 1200.0,
        limit: 2000.0,
        percentage: 60.0,
        level: AdvisoryLevel.moderate,
        unit: 'mg',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return NutrientRowWidget(
                  evaluation: eval,
                  isRelatedToUserCondition: true,
                  colorScheme: Theme.of(context).colorScheme,
                  loc: AppLocalizations.of(context)!,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hypertension - Sodium'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('1,200mg / 2,000mg'), findsOneWidget);
    });
  });
}

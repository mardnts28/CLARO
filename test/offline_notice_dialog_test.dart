import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claro/models/product_model.dart';
import 'package:claro/core/utils/success_feedback_utils.dart';

void main() {
  group('Product isOfflineFallback tests', () {
    test('default value is false', () {
      final product = Product(
        id: 'test_id',
        name: 'Test Product',
        brand: 'Test Brand',
        nutritionalFacts: NutritionalFacts(),
      );
      expect(product.isOfflineFallback, isFalse);
    });

    test('isOfflineFallback can be set to true and preserved in copyWith', () {
      final product = Product(
        id: 'test_id',
        name: 'Test Product',
        brand: 'Test Brand',
        nutritionalFacts: NutritionalFacts(),
        isOfflineFallback: true,
      );
      expect(product.isOfflineFallback, isTrue);

      final copy = product.copyWith(name: 'Updated Name');
      expect(copy.isOfflineFallback, isTrue);
      expect(copy.name, equals('Updated Name'));
    });

    test('serialization toJson and fromJson preserves isOfflineFallback', () {
      final product = Product(
        id: 'test_id',
        name: 'Test Product',
        brand: 'Test Brand',
        nutritionalFacts: NutritionalFacts(),
        isOfflineFallback: true,
      );
      final json = product.toJson();
      expect(json['isOfflineFallback'], isTrue);

      final revived = Product.fromJson(json);
      expect(revived.isOfflineFallback, isTrue);
    });
  });

  group('SuccessFeedbackUtils offline dialog widget test', () {
    testWidgets('renders dialog with correct title, message, and button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  SuccessFeedbackUtils.showOfflineNoticeDialog(
                    context,
                    title: 'No Internet Connection',
                    message:
                        'Connect to mobile data or Wi-Fi to load full nutritional details.',
                    buttonText: 'Got it',
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Tap button to show dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog contents
      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(
        find.text(
            'Connect to mobile data or Wi-Fi to load full nutritional details.'),
        findsOneWidget,
      );
      expect(find.text('Got it'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

      // Tap 'Got it' to dismiss
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      // Verify dialog is dismissed
      expect(find.text('No Internet Connection'), findsNothing);
    });

    testWidgets('renders voice assistant offline dialog with correct message',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  SuccessFeedbackUtils.showOfflineNoticeDialog(
                    context,
                    title: 'No Internet Connection',
                    message:
                        'Please connect to mobile data or Wi-Fi to use the Voice Assistant.',
                    buttonText: 'Got it',
                  );
                },
                child: const Text('Open Voice Offline Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Voice Offline Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(
        find.text(
            'Please connect to mobile data or Wi-Fi to use the Voice Assistant.'),
        findsOneWidget,
      );
      expect(find.text('Got it'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });
  });
}

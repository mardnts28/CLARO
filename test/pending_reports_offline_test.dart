import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:claro/services/pending_reports_service.dart';
import 'package:claro/core/utils/success_feedback_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PendingReportsService Offline Queueing Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('queuing a report updates pendingCountNotifier and persists in SharedPreferences', () async {
      final service = PendingReportsService();
      expect(service.pendingCountNotifier.value, equals(0));

      await service.queueReport(
        productName: 'Century Tuna Flakes in Oil',
        category: 'canned fish',
        reportedBy: 'user_123',
        userEmail: 'user@test.com',
        userName: 'Test User',
        frontImagePath: '/mock/path/front.jpg',
        backImagePath: '/mock/path/back.jpg',
        additionalBackImagePaths: ['/mock/path/back2.jpg'],
      );

      expect(service.pendingCountNotifier.value, equals(1));

      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('pending_unknown_product_reports');
      expect(list, isNotNull);
      expect(list!.length, equals(1));
      expect(list.first, contains('Century Tuna Flakes in Oil'));
      expect(list.first, contains('user_123'));
    });
  });

  group('SuccessFeedbackUtils showQueuedNoticeDialog Widget Test', () {
    testWidgets('renders queued dialog with hourglass icon, custom title and message',
        (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  SuccessFeedbackUtils.showQueuedNoticeDialog(
                    context,
                    title: 'Report Saved Offline',
                    message:
                        'Your report has been saved offline and will be submitted automatically when you reconnect to the internet.',
                    buttonText: 'Got it',
                    onDismiss: () {
                      dismissed = true;
                    },
                  );
                },
                child: const Text('Open Queued Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Queued Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Report Saved Offline'), findsOneWidget);
      expect(
        find.text(
            'Your report has been saved offline and will be submitted automatically when you reconnect to the internet.'),
        findsOneWidget,
      );
      expect(find.text('Got it'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      expect(find.text('Report Saved Offline'), findsNothing);
      expect(dismissed, isTrue);
    });
  });
}

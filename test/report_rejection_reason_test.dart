import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claro/models/report_model.dart';
import 'package:claro/screens/report_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportModel Rejection Reason Tests', () {
    test('ReportModel holds rejectionReason with default empty string', () {
      final report = ReportModel(
        id: 'rep_1',
        dateSubmitted: DateTime.now(),
        productDescription: 'A test snack',
        productName: 'Chippy Barbecue',
        category: 'snacks',
        reportedBy: 'user_456',
        status: 'Pending',
        userEmail: 'user@example.com',
        userName: 'Juan Dela Cruz',
      );

      expect(report.rejectionReason, isEmpty);
      expect(report.toMap()['rejectionReason'], isEmpty);
    });

    test('ReportModel serializes rejectionReason correctly', () {
      final report = ReportModel(
        id: 'rep_2',
        dateSubmitted: DateTime.now(),
        productDescription: 'A test beverage',
        productName: 'Sample Drink',
        category: 'beverages',
        reportedBy: 'user_789',
        status: 'Rejected',
        rejectionReason: 'Blurry nutrition facts image',
        userEmail: 'user2@example.com',
        userName: 'Maria Santos',
      );

      expect(report.rejectionReason, equals('Blurry nutrition facts image'));
      final map = report.toMap();
      expect(map['rejectionReason'], equals('Blurry nutrition facts image'));
      expect(map['status'], equals('Rejected'));
    });
  });

  group('ReportDetailScreen Rejection Reason Widget Tests', () {
    testWidgets('shows highlighted Reason for Rejection card when status is rejected and reason is provided',
        (tester) async {
      final rejectedReport = ReportModel(
        id: 'rep_rej',
        dateSubmitted: DateTime(2026, 9, 18, 10, 30),
        productDescription: 'Snack description',
        productName: 'Crispy Crackers',
        category: 'snacks',
        reportedBy: 'user_1',
        status: 'Rejected',
        rejectionReason: 'The nutrition label photo is not clear and readable.',
        userEmail: 'tester@claro.ph',
        userName: 'Test User',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReportDetailScreen(report: rejectedReport),
        ),
      );

      expect(find.text('Report Details'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Reason for Rejection'), findsOneWidget);
      expect(
        find.text('The nutrition label photo is not clear and readable.'),
        findsOneWidget,
      );
    });

    testWidgets('does NOT show Reason for Rejection when status is Approved',
        (tester) async {
      final approvedReport = ReportModel(
        id: 'rep_app',
        dateSubmitted: DateTime(2026, 9, 18, 10, 30),
        productDescription: 'Snack description',
        productName: 'Crispy Crackers',
        category: 'snacks',
        reportedBy: 'user_1',
        status: 'Approved',
        rejectionReason: '',
        userEmail: 'tester@claro.ph',
        userName: 'Test User',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReportDetailScreen(report: approvedReport),
        ),
      );

      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Reason for Rejection'), findsNothing);
    });

    testWidgets('does NOT show Reason for Rejection when status is Pending',
        (tester) async {
      final pendingReport = ReportModel(
        id: 'rep_pend',
        dateSubmitted: DateTime(2026, 9, 18, 10, 30),
        productDescription: 'Snack description',
        productName: 'Crispy Crackers',
        category: 'snacks',
        reportedBy: 'user_1',
        status: 'Pending',
        rejectionReason: '',
        userEmail: 'tester@claro.ph',
        userName: 'Test User',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReportDetailScreen(report: pendingReport),
        ),
      );

      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Reason for Rejection'), findsNothing);
    });

    testWidgets('does NOT show Reason for Rejection when status is Rejected but reason is empty',
        (tester) async {
      final rejectedEmptyReasonReport = ReportModel(
        id: 'rep_empty_reason',
        dateSubmitted: DateTime(2026, 9, 18, 10, 30),
        productDescription: 'Snack description',
        productName: 'Crispy Crackers',
        category: 'snacks',
        reportedBy: 'user_1',
        status: 'Rejected',
        rejectionReason: '',
        userEmail: 'tester@claro.ph',
        userName: 'Test User',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReportDetailScreen(report: rejectedEmptyReasonReport),
        ),
      );

      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Reason for Rejection'), findsNothing);
    });
  });
}

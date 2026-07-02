import 'package:flutter_test/flutter_test.dart';
import 'package:claro/main.dart';

void main() {
  testWidgets('CLARO app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ClaroApp());
    // Basic smoke test — app should render without crashing
    expect(find.text('Tap anywhere to scan'), findsOneWidget);
  });
}

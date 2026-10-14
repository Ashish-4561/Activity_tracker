import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:activity_tracker/main.dart';

void main() {
  testWidgets('renders activity tracker app', (WidgetTester tester) async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {}
    await tester.pumpWidget(const ActivityTrackerApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle(const Duration(milliseconds: 1500));

    expect(find.byType(ActivityTrackerApp), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_zone_app/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const QuietZoneApp());
    expect(find.text('Sound Monitor'), findsOneWidget);
  });
}

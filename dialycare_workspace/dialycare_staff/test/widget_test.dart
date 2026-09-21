import 'package:flutter_test/flutter_test.dart';

import 'package:dialycare_staff/main.dart';

void main() {
  testWidgets('staff dashboard is rendered', (WidgetTester tester) async {
    await tester.pumpWidget(const DialyCareApp());
    expect(find.text('Good Morning!'), findsOneWidget);
    expect(find.text("Today's Schedule"), findsOneWidget);
  });
}

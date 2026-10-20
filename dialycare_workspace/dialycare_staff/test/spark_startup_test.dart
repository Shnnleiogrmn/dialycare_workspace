import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dialycare_staff/main.dart';

void main() {
  testWidgets(
    'normal startup requires shared Firebase sign-in instead of sample data',
    (tester) async {
      await tester.pumpWidget(const DialyCareApp());
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back!'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Staff Email'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);
      expect(find.text('Sign Up'), findsNothing);
      expect(find.text('Forgot password?'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

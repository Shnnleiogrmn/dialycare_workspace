import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dialycare_staff/screens/staff_portal.dart';
import 'package:dialycare_staff/services/staff_store.dart';

import '../../core_shared/test/helpers/concern_fake.dart';

void main() {
  testWidgets(
    'Staff inbox filters, preserves original, responds, resolves and closes',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = ConcernFake();
      await service.submit(
        newConcernId(),
        'Feedback',
        'Positive feedback',
        'Original message',
        'Other',
      );
      await service.submit(
        newConcernId(),
        'Complaint',
        'Different subject',
        'Other original',
        'Other',
      );
      final store = StaffStore(memoryOnly: true, concerns: service);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: StaffPortal(store: store, now: DateTime(2026, 10, 24)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Feedback & Concerns'));
      await tester.pumpAndSettle();
      expect(find.text('Submitted: 2'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complaint').last);
      await tester.pumpAndSettle();
      expect(find.text('Positive feedback'), findsNothing);
      expect(find.text('Different subject'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All types').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Under Review').last);
      await tester.pumpAndSettle();
      expect(find.text('No concerns found.'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('All statuses').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search concerns'),
        'Positive',
      );
      await tester.pumpAndSettle();
      expect(find.text('Different subject'), findsNothing);
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.text('Original message'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Response to Patient/Relative'),
        'Thank you for your feedback.',
      );
      await tester.tap(find.text('Send Response'));
      await tester.pumpAndSettle();
      expect(service.records.first.values['message'], 'Original message');
      expect(service.records.first.status, 'Under Review');
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.text('Thank you for your feedback.'), findsOneWidget);
      await tester.tap(find.text('Mark Resolved'));
      await tester.pumpAndSettle();
      expect(service.records.first.status, 'Resolved');
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.text('Send Response'), findsNothing);
      await tester.tap(find.text('Close Concern'));
      await tester.pumpAndSettle();
      expect(service.records.first.status, 'Closed');
      expect(service.records.first.values['message'], 'Original message');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}

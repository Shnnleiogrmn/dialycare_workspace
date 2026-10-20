import 'package:flutter/material.dart';
import 'package:core_shared/core_shared.dart' show SessionRecord;
import 'package:dialycare_staff/widgets/patient_details.dart' show ViewAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:dialycare_staff/main.dart';
import 'package:dialycare_staff/models/patient.dart';
import 'package:dialycare_staff/models/notification_delivery.dart';
import 'package:dialycare_staff/services/staff_store.dart';

Future<void> notificationUiFlow(WidgetTester tester) async {
  final store = StaffStore(memoryOnly: true);
  store.sessions = store.sessions
      .map(
        (s) => SessionRecord.fromJson({
          ...s.toJson(),
          'plannedDurationMinutes': 240,
        }),
      )
      .toList();
  store.patients[0] = Patient.fromJson({
    ...store.patients[0].toJson(),
    'contact': '+639171234567',
    'companions': [
      const Companion(
        id: 'R-UI',
        name: 'Example Relative',
        relationship: 'Son',
        contact: '+639181234567',
      ).toJson(),
    ],
  });
  await tester.pumpWidget(
    DialyCareApp(store: store, now: DateTime.now().copyWith(hour: 9)),
  );
  await tester.pumpAndSettle();
  Future<void> tap(String label) async {
    final f = label == 'View' ? find.text(label).first : find.text(label).last;
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  await tap('View');
  expect(find.text('Account Status: Not Activated'), findsNWidgets(2));
  expect(find.text('App Not Registered'), findsNothing);
  expect(
    find.textContaining('Backend registration has not been verified'),
    findsNothing,
  );
  await tap('Send Reminder');
  expect(find.byKey(const ValueKey('reminder-message')), findsOneWidget);
  expect(find.textContaining('no message will be sent'), findsOneWidget);
  for (var i = 0; i < 2; i++) {
    await tester.ensureVisible(find.byType(Checkbox).at(i));
    await tester.tap(find.byType(Checkbox).at(i));
    await tester.pumpAndSettle();
  }
  await tap('Send Reminder');
  expect(find.text('Select at least one recipient.'), findsOneWidget);
  expect(store.deliveryHistory, isEmpty);
  await tester.ensureVisible(find.byType(Checkbox).first);
  await tester.tap(find.byType(Checkbox).first);
  await tester.pumpAndSettle();
  await tap('Send Reminder');
  expect(find.text('Delivery Results'), findsOneWidget);
  expect(store.deliveryHistory.single.status, DeliveryStatus.failed);
  expect(find.textContaining('SMS backend is not configured'), findsOneWidget);
  await tap('Close');
  await tap('Sessions');
  await tap('View');
  await tap('Change Status');
  await tester.tap(find.byKey(const ValueKey('session-status-selector')));
  await tester.pumpAndSettle();
  await tap('Completed');
  await tap('Update Status');
  await tap('Confirm');
  final completedTab = find.textContaining('Completed (').first;
  await tester.ensureVisible(completedTab);
  await tester.tap(completedTab);
  await tester.pumpAndSettle();
  await tap('View');
  await tap('Change Status');
  await tester.tap(find.byKey(const ValueKey('session-status-selector')));
  await tester.pumpAndSettle();
  await tap('Ready for Pick Up');
  await tap('Update Status');
  await tap('Confirm');
  expect(
    store.notificationEvents
        .where((e) => e.type == NotificationType.pickup)
        .length,
    1,
  );
  expect(store.deliveryHistory.length, 5);
  await tap('Notification');
  expect(find.text('Pickup Notification'), findsWidgets);
  expect(find.textContaining('SMS • Failed'), findsWidgets);
  await tap('Mark all as read');
  expect(store.deliveryHistory.every((d) => d.read), isTrue);
  await tap('Schedules');
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  final upcomingView = find.byWidgetPredicate(
    (w) => w is ViewAction && w.session?.id == 'S-8',
  );
  await Scrollable.ensureVisible(tester.element(upcomingView), alignment: .3);
  await tester.pumpAndSettle();
  await tester.tap(upcomingView);
  await tester.pumpAndSettle();
  await tap('Edit Schedule');
  await tester.enterText(
    find.widgetWithText(TextField, 'Assigned room'),
    'Room 99',
  );
  await tap('Save');
  expect(store.notificationEvents.last.type, NotificationType.scheduleUpdated);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  store.dispose();
}

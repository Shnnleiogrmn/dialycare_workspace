import 'package:core_shared/core_shared.dart';
import 'package:dialycare_staff/models/notification_delivery.dart';
import 'package:dialycare_staff/services/notifications/providers.dart';
import 'package:dialycare_staff/services/staff_store.dart';
import 'package:dialycare_staff/widgets/mobile_access_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Staff creates and cancels pending PIN access without an email field',
    (tester) async {
      final pin = generateTemporaryPin();
      var creates = 0, cancels = 0;
      final store = StaffStore(
        memoryOnly: true,
        shared: true,
        issueActivation: (role, pid, rid) async {
          expect(role, 'patient');
          expect(pid, 'DC-001');
          expect(rid, 'DC-001');
          creates++;
          return {'pin': pin};
        },
        cancelMobileAccess: (role, rid) async {
          cancels++;
        },
      );
      addTearDown(store.dispose);
      const recipient = NotificationRecipient(
        id: 'DC-001',
        patientId: 'DC-001',
        name: 'Anna Marie',
        phone: '',
        type: RecipientType.patient,
        registration: AppRegistration(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MobileAccessDetails(recipient: recipient, store: store),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Create Mobile Access'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.text('Verified account email'), findsNothing);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Create Mobile Access'),
      );
      await tester.pumpAndSettle();
      expect(creates, 1);
      expect(find.text('Mobile Access Created'), findsOneWidget);
      expect(find.text(pin), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Regenerate Temporary PIN'), findsOneWidget);
      await tester.tap(find.text('Cancel Mobile Access'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Cancel Mobile Access'),
      );
      await tester.pumpAndSettle();
      expect(cancels, 1);
      expect(find.text('Account Status: Not Activated'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Schedule-only summaries cannot create or regenerate account access',
    (tester) async {
      final store = StaffStore(
        memoryOnly: true,
        shared: true,
        issueActivation: (a, b, c) async => {'pin': generateTemporaryPin()},
      );
      addTearDown(store.dispose);
      const recipient = NotificationRecipient(
        id: 'REL-001',
        patientId: 'DC-001',
        name: 'Robert',
        phone: '',
        type: RecipientType.relative,
        registration: AppRegistration(),
        mobileAccount: MobileAccount(
          status: MobileAccountStatus.activationPending,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileAccessDetails(
              recipient: recipient,
              store: store,
              manageAccess: false,
            ),
          ),
        ),
      );
      expect(find.text('Account Status: Activation Pending'), findsOneWidget);
      expect(find.text('Regenerate Temporary PIN'), findsNothing);
      expect(find.text('Create Mobile Access'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

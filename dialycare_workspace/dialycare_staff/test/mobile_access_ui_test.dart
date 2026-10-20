import 'package:core_shared/core_shared.dart';
import 'package:dialycare_staff/models/patient.dart';
import 'package:dialycare_staff/services/staff_store.dart';
import 'package:dialycare_staff/widgets/patient_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Schedule Details keeps reminder/edit and compact account statuses without delivery diagnostics',
    (tester) async {
      final store = StaffStore(memoryOnly: true, shared: true);
      addTearDown(store.dispose);
      final person = store.patients.first;
      final session = store.sessions.first;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPatientDetails(
                  context,
                  person,
                  store: store,
                  session: session,
                  title: 'Schedule Details',
                ),
                child: const Text('Open schedule'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open schedule'));
      await tester.pumpAndSettle();
      expect(find.text('Schedule Details'), findsOneWidget);
      expect(find.text('Send Reminder'), findsOneWidget);
      expect(find.text('Edit Schedule'), findsOneWidget);
      expect(find.text('Device / delivery status'), findsNothing);
      expect(find.textContaining('Backend registration'), findsNothing);
      expect(find.textContaining('Account ID:'), findsNothing);
      expect(find.textContaining('Push Not Configured'), findsNothing);
      expect(
        find.textContaining('Manage Mobile Access in Patients'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Patient details use actual account status for both roles, separately from delivery',
    (tester) async {
      final store = StaffStore(memoryOnly: true, shared: true);
      addTearDown(store.dispose);
      final person = Patient(
        id: 'TEST-001',
        publicId: 'DC-000001',
        name: 'Test Patient',
        age: 40,
        gender: 'Other',
        contact: '',
        room: 'Test Room',
        mobileAccount: MobileAccount(
          status: MobileAccountStatus.active,
          activatedAt: DateTime(2026, 10, 18),
        ),
        companions: const [
          Companion(
            id: 'TEST-R001',
            publicId: 'R-000001',
            name: 'Test Relative',
            relationship: 'Other',
            mobileAccount: MobileAccount(status: MobileAccountStatus.disabled),
          ),
        ],
      );
      store.patients = [person];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showPatientDetails(context, person, store: store),
                child: const Text('Details'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.text('Account Status: Active'), findsOneWidget);
      expect(find.text('Account Status: Disabled'), findsOneWidget);
      expect(find.text('Device / delivery status'), findsNothing);
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Medical Information'), findsOneWidget);
      expect(find.textContaining('R-000001'), findsWidgets);
      expect(find.textContaining('TEST-R001'), findsNothing);
      expect(find.textContaining('Activated:'), findsOneWidget);
      expect(find.text('Issue activation'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dialycare_staff/main.dart';
import 'package:dialycare_staff/services/staff_store.dart';

void main() {
  for (final size in [
    const Size(1400, 1000),
    const Size(1920, 1080),
    const Size(900, 600),
    const Size(390, 650),
  ]) {
    testWidgets('screens remain usable at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = StaffStore(
        memoryOnly: true,
        now: DateTime(2026, 10, 14, 9),
      );
      await tester.pumpWidget(
        DialyCareApp(store: store, now: DateTime(2026, 10, 14, 9)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Good Morning!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final label in [
        'Patients',
        'Schedules',
        'Sessions',
        'Notification',
        'Reports',
        'Settings',
        'Dashboard',
      ]) {
        if (size.width < 850) {
          await tester.tap(find.byTooltip('Open navigation menu'));
          await tester.pumpAndSettle();
        }
        final item = find.text(label).first;
        await tester.ensureVisible(item);
        await tester.pumpAndSettle();
        await tester.tap(item);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    });
  }
  testWidgets('patient contact search, custom details and profile actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = StaffStore(memoryOnly: true);
    await tester.pumpWidget(DialyCareApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View').first);
    await tester.pumpAndSettle();
    expect(find.text('Schedule Details'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Patients').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      store.patients.first.contact,
    );
    await tester.pump();
    expect(find.text(store.patients.first.name), findsOneWidget);
    expect(find.text(store.patients.last.name), findsNothing);
    await tester.enterText(find.byType(TextField), 'no-such-patient');
    await tester.pump();
    expect(find.text('No patients found.'), findsOneWidget);
    await tester.tap(find.text('Staff').last);
    await tester.pumpAndSettle();
    expect(find.text('Your Profile'), findsOneWidget);
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(store.signedIn, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
  test(
    'schedule mutations, duplicate protection and linked deletion',
    () async {
      final store = StaffStore(memoryOnly: true);
      final patient = store.patients.first;
      final count = store.sessions.length;
      final date = DateTime(2026, 11, 20, 14, 30);
      await store.addSchedule(patient, date, 'Batch B');
      expect(store.sessions.length, count + 1);
      await expectLater(
        store.addSchedule(patient, date, 'Batch B'),
        throwsStateError,
      );
      expect(store.sessions.length, count + 1);
      await store.markAllRead();
      expect(store.notifications.every((n) => n.read), isTrue);
      await store.deletePatient(patient.id);
      expect(store.sessions.any((s) => s.patientId == patient.id), isTrue);
      expect(store.patientFor(patient.id).archived, isTrue);
      store.dispose();
    },
  );
  test('workspace password rejects incorrect credentials', () async {
    final store = StaffStore(memoryOnly: true);
    await store.changePassword('', 'test-password');
    store.logOut();
    expect(await store.signIn('incorrect'), isFalse);
    expect(store.signedIn, isFalse);
    expect(await store.signIn('test-password'), isTrue);
    expect(store.signedIn, isTrue);
    store.dispose();
  });
}

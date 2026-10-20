import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dialycare_staff/main.dart';
import 'package:dialycare_staff/services/staff_store.dart';
import 'package:dialycare_staff/widgets/pickers.dart';

void main() {
  test('saved workspace reloads and failed writes roll back', () async {
    String? saved;
    final store = StaffStore(
      readData: () async => saved,
      writeData: (data) async {
        saved = data;
      },
    );
    final date = DateTime(2026, 12, 20, 13);
    await store.addSchedule(store.patients.first, date, 'Batch C');
    await store.markAllRead();
    final loaded = StaffStore(
      readData: () async => saved,
      writeData: (data) async {
        saved = data;
      },
    );
    await loaded.load();
    expect(
      loaded.sessions.any((s) => s.start == date && s.batch == 'Batch C'),
      isTrue,
    );
    expect(loaded.notifications.every((n) => n.read), isTrue);
    final failed = StaffStore(
      readData: () async => saved,
      writeData: (_) async => throw StateError('disk full'),
    );
    await failed.load();
    final count = failed.patients.length;
    await expectLater(
      failed.deletePatient(failed.patients.first.id),
      throwsStateError,
    );
    expect(failed.patients.length, count);
    final damaged = StaffStore(
      readData: () async => 'broken JSON',
      writeData: (_) async => fail('Must not overwrite damaged data'),
    );
    await damaged.load();
    expect(damaged.loadError, isNotNull);
    await expectLater(damaged.markAllRead(), throwsStateError);
    store.dispose();
    loaded.dispose();
    failed.dispose();
    damaged.dispose();
  });
  testWidgets(
    'patient save, relatives, medical picker, schedule and read state',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = StaffStore(memoryOnly: true);
      await tester.pumpWidget(DialyCareApp(store: store));
      await tester.pumpAndSettle();
      Future<void> tap(String label) async {
        final f = find.text(label).first;
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      Future<void> enter(String key, String value) async {
        final f = find.byKey(ValueKey(key));
        await tester.ensureVisible(f);
        await tester.enterText(f, value);
      }

      await tap('Patients');
      await tap('+ Add Patient');
      await tap('Save');
      expect(find.textContaining('Enter a name, date'), findsOneWidget);
      await enter('patient-name', 'Test Person');
      await enter('patient-contact', '09123456789');
      await enter('patient-address', 'Test address');
      await tester.tap(find.byKey(const ValueKey('patient-dob')));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      await tap('Set');
      await tap('Relative Info');
      await enter('relative-name-0', 'Test Relative');
      await enter('relative-contact-0', '09987654321');
      await tap('Medical Info');
      await tap('--');
      await tap('O+');
      await tap('Set');
      await tap('Save');
      final added = store.patients.singleWhere((p) => p.name == 'Test Person');
      expect(added.birthDate, isNotNull);
      expect(added.bloodType, 'O+');
      expect(added.companions.single.name, 'Test Relative');
      expect(find.text('Test Person'), findsOneWidget);
      await tap('Schedules');
      await tap('+ Add Schedule');
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Test Person');
      await tester.pump();
      final selectors = find.byType(TextButton);
      expect(selectors, findsWidgets);
      await tap('Add');
      await tap('Confirm');
      expect(store.sessions.any((s) => s.patientId == added.id), isTrue);
      await tap('Notification');
      await tap('Mark all as read');
      expect(store.notifications.every((n) => n.read), isTrue);
      await tap('Reports');
      await tester.tap(find.byType(SelectorButton).first);
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      await tap('Set');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
}

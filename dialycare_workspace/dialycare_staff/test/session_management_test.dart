import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dialycare_staff/main.dart';
import 'package:dialycare_staff/models/session.dart';
import 'package:dialycare_staff/models/session_batch.dart';
import 'package:dialycare_staff/models/notification_delivery.dart';
import 'package:dialycare_staff/services/staff_store.dart';
import 'package:dialycare_staff/widgets/staff_components.dart';

StaffStore sessionFixture({
  Future<String?> Function()? readData,
  Future<void> Function(String)? writeData,
}) {
  final store = StaffStore(
    memoryOnly: writeData == null,
    readData: readData,
    writeData: writeData,
  );
  final d = DateTime.now();
  SessionRecord s(String id, int patient, String batch, int h, int m) =>
      SessionRecord(
        plannedDurationMinutes: 240,
        id: id,
        patientId: store.patients[patient].id,
        start: DateTime(d.year, d.month, d.day, h, m),
        room: 'Room ${patient + 1}',
        batch: batch,
        status: SessionStatus.pending,
      );
  store.sessions = [
    s('A3', 2, 'Batch A', 9, 0),
    s('C2', 5, 'Batch C', 10, 30),
    s('B2', 4, 'Batch B', 9, 15),
    s('A1', 0, 'Batch A', 8, 0),
    s('C1', 3, 'Batch C', 10, 0),
    s('B1', 3, 'Batch B', 9, 0),
    s('A2', 1, 'Batch A', 8, 15),
  ];
  store.notifications = [];
  return store;
}

void main() {
  test('legacy status labels migrate to typed states', () {
    expect(SessionStatus.fromStorage('Missing'), SessionStatus.missed);
    expect(
      SessionStatus.fromStorage('Ready for Pick Up'),
      SessionStatus.readyForPickUp,
    );
    expect(SessionStatus.fromStorage('Waiting'), SessionStatus.waiting);
    expect(() => SessionStatus.fromStorage('arbitrary'), throwsFormatException);
  });
  test(
    'batches and rows are deterministic after changes and additions',
    () async {
      final store = sessionFixture();
      var groups = groupSessionsByBatch(store.sessions);
      expect(groups.map((g) => g.name), ['Batch A', 'Batch B', 'Batch C']);
      expect(groups.first.sessions.map((s) => s.id), ['A1', 'A2', 'A3']);
      expect(groups[1].sessions.map((s) => s.id), ['B1', 'B2']);
      expect(groups[2].sessions.map((s) => s.id), ['C1', 'C2']);
      final d = store.sessions.first.start;
      await store.updateSchedule(
        'A1',
        start: DateTime(d.year, d.month, d.day, 7, 45),
        room: 'Room 1',
        batch: 'Batch B',
      );
      await store.changeSessionStatus('A1', SessionStatus.inProgress);
      groups = groupSessionsByBatch(store.sessions);
      expect(groups[1].sessions.first.id, 'A1');
      expect(groups.first.sessions.any((s) => s.id == 'A1'), isFalse);
      await store.addSchedule(
        store.patients[1],
        DateTime(d.year, d.month, d.day + 1, 7, 30),
        'Batch C',
      );
      groups = groupSessionsByBatch(store.sessions);
      expect(groups.last.sessions.last.patientId, store.patients[1].id);
      final names = ['Batch AA', 'Batch Z', 'Batch C', 'Batch A', 'Batch B']
        ..sort(compareBatchNames);
      expect(names, ['Batch A', 'Batch B', 'Batch C', 'Batch Z', 'Batch AA']);
      expect((['Batch 10', 'Batch 2', 'Batch 1']..sort(compareBatchNames)), [
        'Batch 1',
        'Batch 2',
        'Batch 10',
      ]);
      store.dispose();
    },
  );
  test(
    'status persists, completion is separate from pickup, missed has no pickup',
    () async {
      String? saved;
      final store = sessionFixture(
        readData: () async => saved,
        writeData: (data) async {
          saved = data;
        },
      );
      await store.changeSessionStatus('A1', SessionStatus.inProgress);
      expect(
        store.notificationEvents.single.type,
        NotificationType.sessionStarted,
      );
      await store.changeSessionStatus('A1', SessionStatus.completed);
      expect(store.notificationEvents.length, 2);
      expect(store.sessions.singleWhere((s) => s.id == 'A1').completed, isTrue);
      await store.changeSessionStatus('A1', SessionStatus.readyForPickUp);
      await store.changeSessionStatus('A1', SessionStatus.readyForPickUp);
      expect(
        store.notificationEvents
            .where((e) => e.type == NotificationType.pickup)
            .length,
        1,
      );
      final events = store.notificationEvents.length;
      await store.changeSessionStatus('A2', SessionStatus.missed);
      expect(store.notificationEvents.length, events);
      expect(store.sessions.singleWhere((s) => s.id == 'A2').finished, isTrue);
      expect(
        store.sessions.singleWhere((s) => s.id == 'A2').completed,
        isFalse,
      );
      final loaded = StaffStore(
        readData: () async => saved,
        writeData: (data) async {
          saved = data;
        },
      );
      await loaded.load();
      expect(
        loaded.sessions.singleWhere((s) => s.id == 'A1').status,
        SessionStatus.readyForPickUp,
      );
      expect(
        loaded.sessions.singleWhere((s) => s.id == 'A2').status,
        SessionStatus.missed,
      );
      expect(
        groupSessionsByBatch(loaded.sessions).first.sessions.map((s) => s.id),
        ['A1', 'A2', 'A3'],
      );
      await loaded.changeSessionStatus('A1', SessionStatus.readyForPickUp);
      expect(loaded.notificationEvents.length, events);
      store.dispose();
      loaded.dispose();
    },
  );
  test(
    'failed persistence rolls back; stale and signed-out edits are rejected',
    () async {
      final failed = sessionFixture(
        writeData: (_) async => throw StateError('write failed'),
      );
      await expectLater(
        failed.changeSessionStatus('A1', SessionStatus.inProgress),
        throwsStateError,
      );
      expect(
        failed.sessions.singleWhere((s) => s.id == 'A1').status,
        SessionStatus.pending,
      );
      expect(failed.notificationEvents, isEmpty);
      expect(failed.sessionEvents, isEmpty);
      expect(failed.deliveryHistory, isEmpty);
      failed.dispose();
      final store = sessionFixture();
      await store.changeSessionStatus(
        'A1',
        SessionStatus.inProgress,
        expectedRevision: 0,
      );
      await expectLater(
        store.changeSessionStatus(
          'A1',
          SessionStatus.completed,
          expectedRevision: 0,
        ),
        throwsStateError,
      );
      store.logOut();
      await expectLater(
        store.changeSessionStatus('A1', SessionStatus.completed),
        throwsStateError,
      );
      store.dispose();
    },
  );
  test(
    'notification recording failure does not misreport a persisted status',
    () async {
      var writes = 0;
      final store = sessionFixture(
        writeData: (_) async {
          if (++writes > 1) throw StateError('outbox unavailable');
        },
      );
      final result = await store.changeSessionStatus(
        'A1',
        SessionStatus.inProgress,
      );
      expect(result.deliveryWarning, isNotNull);
      expect(
        store.sessions.singleWhere((s) => s.id == 'A1').status,
        SessionStatus.inProgress,
      );
      expect(store.notificationEvents.length, 1);
      expect(store.deliveryHistory.single.status, DeliveryStatus.pending);
      store.dispose();
    },
  );
  for (final size in [
    const Size(1920, 1080),
    const Size(1400, 1000),
    const Size(900, 600),
    const Size(390, 650),
  ]) {
    testWidgets('header remains compact at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = sessionFixture();
      await tester.pumpWidget(
        DialyCareApp(store: store, now: DateTime.now().copyWith(hour: 9)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('dashboard-header'))).height,
        lessThan(180),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    });
  }
  testWidgets(
    'confirmation, all status states, dashboard and reports share the same session',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await sessionManagementUiFlow(tester);
    },
  );
}

Future<void> sessionManagementUiFlow(WidgetTester tester) async {
  final store = sessionFixture();
  await tester.pumpWidget(
    DialyCareApp(store: store, now: DateTime.now().copyWith(hour: 9)),
  );
  await tester.pumpAndSettle();
  Future<void> tap(String text) async {
    final f = find.text(text).last;
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  void summary(String title, String count) {
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text(title),
          matching: find.byType(SummaryCard),
        ),
        matching: find.text(count),
      ),
      findsOneWidget,
    );
  }

  Future<void> choose(SessionStatus status, {bool cancel = false}) async {
    await tester.tap(find.byKey(const ValueKey('session-status-selector')));
    await tester.pumpAndSettle();
    await tap(status.label);
    await tap('Update Status');
    expect(find.text('Update Session Status?'), findsOneWidget);
    await tap(cancel ? 'Cancel' : 'Confirm');
  }

  await tap('Sessions');
  await tap('Upcoming (7)');
  expect(find.byKey(const ValueKey('batch-Batch A')), findsOneWidget);
  expect(find.byKey(const ValueKey('batch-Batch B')), findsOneWidget);
  expect(find.byKey(const ValueKey('batch-Batch C')), findsOneWidget);
  await tester.ensureVisible(find.byKey(const ValueKey('manage-A1')));
  await tester.tap(find.byKey(const ValueKey('manage-A1')));
  await tester.pumpAndSettle();
  expect(find.text('Manage Dialysis Session'), findsOneWidget);
  await choose(SessionStatus.inProgress, cancel: true);
  expect(
    store.sessions.singleWhere((s) => s.id == 'A1').status,
    SessionStatus.pending,
  );
  expect(store.notificationEvents, isEmpty);
  await tap('Update Status');
  await tap('Confirm');
  expect(
    store.sessions.singleWhere((s) => s.id == 'A1').status,
    SessionStatus.inProgress,
  );
  await tap('Dashboard');
  summary('Active Sessions', '1');
  summary('Pending', '6');
  await tap('Sessions');
  await tester.ensureVisible(find.byKey(const ValueKey('manage-A1')));
  await tester.tap(find.byKey(const ValueKey('manage-A1')));
  await tester.pumpAndSettle();
  await choose(SessionStatus.completed);
  expect(
    store.notificationEvents.where((e) => e.type == NotificationType.pickup),
    isEmpty,
  );
  await tap('Dashboard');
  summary('Active Sessions', '0');
  summary('Completed', '1');
  await tap('Sessions');
  await tap('Completed (1)');
  await tester.ensureVisible(find.byKey(const ValueKey('manage-A1')));
  await tester.tap(find.byKey(const ValueKey('manage-A1')));
  await tester.pumpAndSettle();
  await choose(SessionStatus.readyForPickUp);
  expect(
    store.notificationEvents
        .where((e) => e.type == NotificationType.pickup)
        .length,
    1,
  );
  await tap('Upcoming (6)');
  await tester.ensureVisible(find.byKey(const ValueKey('manage-A2')));
  await tester.tap(find.byKey(const ValueKey('manage-A2')));
  await tester.pumpAndSettle();
  await choose(SessionStatus.missed);
  await tap('Reports');
  summary('Missed', '1');
  expect(find.text('Jose Reyes'), findsOneWidget);
  expect(find.text('Ready for Pick Up'), findsOneWidget);
  await tap('Sessions');
  await tap('Completed (2)');
  await tester.ensureVisible(find.byKey(const ValueKey('manage-A2')));
  await tester.tap(find.byKey(const ValueKey('manage-A2')));
  await tester.pumpAndSettle();
  await choose(SessionStatus.pending);
  expect(find.text('Upcoming (6)'), findsOneWidget);
  expect(
    store.notificationEvents
        .where((e) => e.type == NotificationType.pickup)
        .length,
    1,
  );
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  store.dispose();
}

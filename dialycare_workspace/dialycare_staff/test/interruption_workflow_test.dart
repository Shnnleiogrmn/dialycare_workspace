import 'dart:convert';

import 'package:core_shared/core_shared.dart';
import 'package:dialycare_staff/services/staff_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pause/resume/restart/end early retains history and blocks stale or terminal changes', () async {
    String? persisted;
    StaffStore create() => StaffStore(
      shared: true,
      readData: () async => persisted,
      writeData: (v) async {
        persisted = v;
      },
    );
    final store = create();
    store.actorUid = 'test-staff';
    store.sessions = [];
    store.notifications = [];
    final patient = store.patients.first;
    await store.addSchedule(patient, DateTime.now(), 'Batch A');
    final id = store.sessions.single.id;
    await expectLater(
      store.changeSessionStatus(
        id,
        SessionStatus.paused,
        reasonCode: 'equipment',
      ),
      throwsStateError,
    );
    await store.changeSessionStatus(id, SessionStatus.inProgress);
    await expectLater(
      store.changeSessionStatus(id, SessionStatus.paused),
      throwsStateError,
    );
    await store.changeSessionStatus(
      id,
      SessionStatus.paused,
      reasonCode: 'equipment',
      note: 'Private note',
    );
    final paused = store.sessions.single;
    expect(
      paused.elapsedAt(DateTime.now()),
      paused.elapsedAt(DateTime.now().add(const Duration(days: 1))),
    );
    final reopened = create();
    await reopened.load();
    expect(reopened.sessions.single.status, SessionStatus.paused);
    expect((await reopened.sessionHistory(id)).last['note'], 'Private note');
    await expectLater(
      reopened.changeSessionStatus(id, SessionStatus.completed),
      throwsStateError,
    );
    await expectLater(
      reopened.changeSessionStatus(
        id,
        SessionStatus.inProgress,
        expectedRevision: 1,
      ),
      throwsStateError,
    );
    await reopened.changeSessionStatus(
      id,
      SessionStatus.inProgress,
      expectedRevision: 2,
    );
    await reopened.changeSessionStatus(
      id,
      SessionStatus.paused,
      reasonCode: 'temporary',
    );
    await reopened.changeSessionStatus(
      id,
      SessionStatus.endedEarly,
      reasonCode: 'clinicalDecision',
    );
    final ended = reopened.sessions.single;
    expect(ended.pauseIntervals.length, 2);
    expect(
      ended.elapsedAt(DateTime.now()),
      ended.elapsedAt(DateTime.now().add(const Duration(days: 10))),
    );
    await expectLater(
      reopened.changeSessionStatus(id, SessionStatus.inProgress),
      throwsStateError,
    );
    final json = jsonDecode(persisted!) as Map;
    expect((json['sessionEvents'] as List).map((e) => e['type']), [
      'START',
      'PAUSE',
      'RESUME',
      'PAUSE',
      'END_EARLY',
    ]);
    store.dispose();
    reopened.dispose();
  });
  test(
    'configured optional capacity and overlapping appointments are enforced',
    () async {
      final store = StaffStore(memoryOnly: true, shared: true);
      store.sessions = [];
      store.notifications = [];
      store.actorRole = 'admin';
      await store.configureBatch({
        'id': 'A',
        'name': 'Batch A',
        'startMinute': 480,
        'endMinute': 720,
        'capacity': 1,
        'active': true,
      });
      final start = DateTime(2026, 11, 2, 8);
      await store.addSchedule(store.patients[0], start, 'Batch A');
      await expectLater(
        store.addSchedule(store.patients[1], start, 'Batch A'),
        throwsStateError,
      );
      await expectLater(
        store.addSchedule(
          store.patients[0],
          start.add(const Duration(hours: 1)),
          'Batch B',
        ),
        throwsStateError,
      );
      expect(store.batches.contains('Batch C'), false);
      await store.changeSessionStatus(
        store.sessions.single.id,
        SessionStatus.cancelled,
        reasonCode: 'transfer',
      );
      await store.addSchedule(store.patients[1], start, 'Batch A');
      expect(store.sessions.length, 2);
      expect(store.sessions.first.status, SessionStatus.cancelled);
      store.dispose();
    },
  );
}

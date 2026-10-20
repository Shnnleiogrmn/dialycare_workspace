import 'package:flutter_test/flutter_test.dart';
import 'package:core_shared/core_shared.dart';

void main() {
  test('multiple pauses freeze active time, extend estimate and persist terminal duration', () {
    final t = DateTime.utc(2026, 10, 21, 8);
    final s = SessionRecord(
      id: 'S',
      patientId: 'P',
      start: t,
      room: 'R',
      batch: 'A',
      status: SessionStatus.paused,
      plannedDurationMinutes: 240,
      actualStartedAt: t,
      pauseSequence: 2,
      pauseIntervals: {
        'p1': PauseInterval(
          pausedAt: t.add(const Duration(minutes: 60)),
          resumedAt: t.add(const Duration(minutes: 75)),
        ),
        'p2': PauseInterval(pausedAt: t.add(const Duration(minutes: 120))),
      },
    );
    expect(
      s.elapsedAt(t.add(const Duration(hours: 3))),
      const Duration(minutes: 105),
    );
    expect(
      s.elapsedAt(t.add(const Duration(hours: 4))),
      const Duration(minutes: 105),
    );
    expect(s.progressAt(t.add(const Duration(hours: 3))), 105 / 240);
    expect(s.estimatedEndAt(t.add(const Duration(hours: 3))), isNull);
    final resumed = SessionRecord.fromJson({
      ...s.toJson(),
      'status': 'In Progress',
      'pauseIntervals': {
        'p1': s.pauseIntervals['p1']!.toJson(),
        'p2': PauseInterval(
          pausedAt: t.add(const Duration(minutes: 120)),
          resumedAt: t.add(const Duration(minutes: 150)),
        ).toJson(),
      },
    });
    expect(
      resumed.estimatedEndAt(t.add(const Duration(hours: 3)))!.toUtc(),
      t.add(const Duration(minutes: 285)),
    );
    final ended = SessionRecord.fromJson({
      ...resumed.toJson(),
      'status': 'Ended Early',
      'endedAt': t.add(const Duration(hours: 3)).toIso8601String(),
    });
    expect(
      ended.elapsedAt(t.add(const Duration(days: 10))),
      const Duration(minutes: 135),
    );
    expect(ended.totalPausedAt(t), const Duration(minutes: 45));
    expect(ended.wallClockAt(t), const Duration(hours: 3));
    expect(ended.estimatedEnd, isNull);
  });
  test('terminal and prestart invalid transitions are rejected', () {
    expect(
      sessionTransitionAllowed(SessionStatus.pending, SessionStatus.paused),
      false,
    );
    expect(
      sessionTransitionAllowed(
        SessionStatus.completed,
        SessionStatus.inProgress,
      ),
      false,
    );
    expect(
      sessionTransitionAllowed(
        SessionStatus.endedEarly,
        SessionStatus.inProgress,
      ),
      false,
    );
    expect(
      sessionTransitionAllowed(SessionStatus.paused, SessionStatus.completed),
      false,
    );
    expect(
      sessionTransitionAllowed(SessionStatus.paused, SessionStatus.inProgress),
      true,
    );
  });
  test('avatars use explicit gender, never inferred identities', () {
    expect(PersonAvatar.assetFor('Female'), 'assets/patient-avatar-female.png');
    expect(PersonAvatar.assetFor('Male'), 'assets/patient-avatar-male.png');
    for (final unknown in [null, '', 'Unknown', 'Other', 'Anna']) {
      expect(PersonAvatar.assetFor(unknown), isNull);
    }
  });
}

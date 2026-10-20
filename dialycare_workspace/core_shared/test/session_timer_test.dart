import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final scheduled = DateTime.utc(2026, 10, 21, 0),
      actual = DateTime.utc(2026, 10, 21, 0, 7);
  SessionRecord session({
    DateTime? end,
    int duration = 240,
    bool started = true,
  }) => SessionRecord(
    id: 'timer',
    patientId: 'private-id',
    start: scheduled,
    room: 'Room 01',
    batch: 'Batch A',
    status: end == null ? SessionStatus.inProgress : SessionStatus.completed,
    plannedDurationMinutes: duration,
    actualStartedAt: started ? actual : null,
    completedAt: end,
    scheduleGroup: ScheduleGroup.mwf,
  );
  test('actual start drives progress and survives serialize/recreate; estimate is not completion', () {
    final restored = SessionRecord.fromJson(session().toJson());
    final now = actual.add(const Duration(hours: 2, minutes: 17, seconds: 35));
    expect(
      restored.elapsedAt(now),
      const Duration(hours: 2, minutes: 17, seconds: 35),
    );
    expect(restored.progressAt(now), closeTo(0.57326, 0.0001));
    expect(
      restored.estimatedEnd!.toUtc(),
      actual.add(const Duration(hours: 4)),
    );
    expect(
      restored.elapsedAt(actual.subtract(const Duration(minutes: 1))),
      Duration.zero,
    );
    expect(session(started: false).elapsedAt(now), isNull);
  });
  test('overdue stays In Progress at 100%; true elapsed continues', () {
    final s = session(duration: 180),
        now = actual.add(const Duration(hours: 4, minutes: 18));
    expect(s.progressAt(now), 1);
    expect(s.elapsedAt(now), const Duration(hours: 4, minutes: 18));
    expect(s.status, SessionStatus.inProgress);
    expect(s.completedAt, isNull);
  });
  test('completion freezes actual duration after reconstruction', () {
    final end = actual.add(const Duration(hours: 4, minutes: 6));
    final restored = SessionRecord.fromJson(session(end: end).toJson());
    expect(
      restored.elapsedAt(end.add(const Duration(days: 3))),
      const Duration(hours: 4, minutes: 6),
    );
    expect(restored.progressAt(end), 1);
  });
  test('weekday groups exclude Sunday and keep canonical codes', () {
    for (var day = 19; day <= 24; day++) {
      final date = DateTime(2026, 10, day);
      expect(ScheduleGroup.forDay(date)?.code, day.isOdd ? 'MWF' : 'TTHS');
    }
    expect(ScheduleGroup.forDay(DateTime(2026, 10, 25)), isNull);
    expect(ScheduleGroup.parse('TThS'), ScheduleGroup.tths);
  });
  testWidgets(
    'local clock ticks and reopening reconstructs elapsed without any write API',
    (tester) async {
      var now = actual;
      final s = session();
      Widget render() => MaterialApp(
        home: Scaffold(
          body: SessionProgress(session: s, clock: () => now),
        ),
      );
      await tester.pumpWidget(render());
      expect(find.text('Elapsed: 00:00:00'), findsOneWidget);
      now = actual.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Elapsed: 00:00:02'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      now = actual.add(const Duration(hours: 1));
      await tester.pumpWidget(render());
      expect(find.text('Elapsed: 01:00:00'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

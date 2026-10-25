import 'package:core_shared/core_shared.dart';
import 'package:dialycare_staff/models/session_batch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 22, 23, 45);
  SessionRecord session(
    String id,
    int day, {
    int hour = 9,
    String batch = 'Batch A',
    SessionStatus status = SessionStatus.pending,
  }) => SessionRecord(
    id: id,
    patientId: 'fixture',
    start: DateTime(2026, 10, day, hour),
    room: 'Test room',
    batch: batch,
    status: status,
  );
  List<String> select(List<SessionRecord> sessions) =>
      nearestUpcomingSessions(sessions, today).map((s) => s.id).toList();

  test('tomorrow is selected when scheduled', () {
    expect(select([session('tomorrow', 23), session('later', 24)]), [
      'tomorrow',
    ]);
  });
  test('empty tomorrow skips to the nearest actual scheduled day', () {
    expect(select([session('later', 26), session('next', 24)]), ['next']);
  });
  test(
    'all sessions on the nearest date are returned, later dates excluded',
    () {
      expect(select([session('a', 23), session('b', 23), session('c', 24)]), [
        'a',
        'b',
      ]);
    },
  );
  test('historical appointments and future terminal records are excluded', () {
    expect(
      select([
        session('old', 21),
        session('done', 23, status: SessionStatus.completed),
        session('cancelled', 23, status: SessionStatus.cancelled),
        session('missed', 23, status: SessionStatus.missed),
        session('valid', 24),
      ]),
      ['valid'],
    );
  });
  test('today is excluded even if its scheduled time is later than now', () {
    expect(
      nearestUpcomingSessions([
        session('today', 22, hour: 23),
      ], DateTime(2026, 10, 22, 8)),
      isEmpty,
    );
  });
  test('no future appointments returns an empty list', () {
    expect(select([session('old', 21), session('today', 22)]), isEmpty);
  });
  test('nearest date sorts by start time then batch and stable identity', () {
    expect(
      select([
        session('late', 23, hour: 11),
        session('b', 23, batch: 'Batch B'),
        session('a', 23),
        session('early', 23, hour: 8),
      ]),
      ['early', 'a', 'b', 'late'],
    );
  });
  test('date comparisons convert UTC timestamps to the local calendar', () {
    final localMidnight = DateTime(2026, 10, 23, 0, 5);
    final s = SessionRecord(
      id: 'utc',
      patientId: 'fixture',
      start: localMidnight.toUtc(),
      room: 'Test room',
      batch: 'Batch A',
      status: SessionStatus.pending,
    );
    expect(select([s]), ['utc']);
  });
  test('ineligible archived patient does not determine the nearest day', () {
    final rows = nearestUpcomingSessions(
      [session('archived', 23), session('active', 24)],
      today,
      eligible: (s) => s.id != 'archived',
    );
    expect(rows.single.id, 'active');
  });
}

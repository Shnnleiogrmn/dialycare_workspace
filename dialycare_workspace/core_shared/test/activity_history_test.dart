import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('history contains terminal sessions and never invents actual treatment time', () {
    SessionRecord s(String id, SessionStatus status) => SessionRecord(
      id: id,
      patientId: 'internal',
      start: DateTime(2026, 10, 21, 8),
      room: 'Room A',
      batch: 'Batch A',
      status: status,
    );
    final items = sessionHistoryItems([
      s('done', SessionStatus.completed),
      s('early', SessionStatus.endedEarly),
      s('missed', SessionStatus.missed),
      s('pending', SessionStatus.pending),
      s('active', SessionStatus.inProgress),
    ], (_) => 'Synthetic Patient • DP-2026-001');
    expect(items, hasLength(3));
    expect(items.every((e) => e.patient.contains('DP-2026-001')), isTrue);
    expect(items.first.details, contains('Actual start: Not recorded'));
    expect(items.first.details, contains('Active duration: Not recorded'));
  });
  test('history filters category, canonical Patient ID, local dates and descending time', () {
    HistoryItem e(String category, String time) => HistoryItem(
      category: category,
      title: 'Completed',
      patient: 'DP-2026-001',
      timestamp: time,
      details: '',
    );
    final rows = [
      e('Sessions', DateTime(2026, 10, 21, 10).toUtc().toIso8601String()),
      e(
        'Feedback & Concerns',
        DateTime(2026, 10, 24, 10).toUtc().toIso8601String(),
      ),
      e('Sessions', DateTime(2026, 10, 24, 11).toUtc().toIso8601String()),
    ];
    final filtered = visibleHistory(
      rows,
      category: 'Sessions',
      search: 'dp-2026-001',
      dates: DateTimeRange(
        start: DateTime(2026, 10, 24),
        end: DateTime(2026, 10, 24),
      ),
    );
    expect(filtered, hasLength(1));
    expect(visibleHistory(rows).first.timestamp, rows.last.timestamp);
    expect(visibleHistory(rows, search: 'unrelated'), isEmpty);
  });
  test('canonical ID login aliases are bounded, preserve legacy identity, and reset by year', () {
    expect(yearlyPatientId(2026, 1), 'DP-2026-001');
    expect(yearlyPatientId(2027, 1), 'DP-2027-001');
    expect(() => yearlyPatientId(2026, 1000), throwsA(isA<BackendException>()));
    expect(
      patientLoginIds('patient', 'DP-2026-001'),
      containsAll(['DC-000001', 'DC-001', 'DP-2026-0001']),
    );
    expect(
      patientLoginIds('patient', 'DP-2027-001'),
      isNot(contains('DC-000001')),
    );
    expect(patientLoginIds('relative', 'R-000001'), ['R-000001']);
  });
}

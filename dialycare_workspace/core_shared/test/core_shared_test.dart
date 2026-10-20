import 'package:flutter_test/flutter_test.dart';
import 'package:core_shared/core_shared.dart';

void main() {
  test('shared status preserves storage compatibility', () {
    for (final status in SessionStatus.values) {
      expect(SessionStatus.fromStorage(status.label), status);
      expect(SessionStatus.fromStorage(status.name), status);
    }
    expect(SessionStatus.fromStorage('Missing'), SessionStatus.missed);
    expect(() => SessionStatus.fromStorage('unknown'), throwsFormatException);
  });
  test('session round trip preserves revision and dates', () {
    final session = SessionRecord(
      id: 'S-1',
      patientId: 'DC-1',
      start: DateTime.utc(2026, 10, 20, 8),
      room: 'Room 03',
      batch: 'Batch A',
      status: SessionStatus.readyForPickUp,
      revision: 4,
    );
    final restored = SessionRecord.fromJson(session.toJson());
    expect(restored.toJson(), session.toJson());
    expect(restored.completed, isTrue);
    expect(restored.finished, isTrue);
    expect(restored.upcoming, isFalse);
  });
  test('account IDs cannot inject another email identity', () {
    expect(
      accountEmail('patient', 'DC-001'),
      'dc-001@patient.dialycare.invalid',
    );
    expect(
      () => accountEmail('relative', 'other@example.com'),
      throwsA(isA<BackendException>()),
    );
  });
  test('unconfigured server fails clearly', () async {
    final api = BackendClient(token: () async => null);
    await expectLater(api.call('mobileData'), throwsA(isA<BackendException>()));
  });
}

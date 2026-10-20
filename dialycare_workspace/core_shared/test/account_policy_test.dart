import 'package:core_shared/core_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new password and confirmation policy handles boundaries without truncation', () {
    expect(
      validateMobilePassword('1234567'),
      'Password must contain at least 8 characters.',
    );
    expect(validateMobilePassword('12345678'), isNull);
    expect(validateMobilePassword('1234567890123456'), isNull);
    expect(
      validateMobilePassword('12345678901234567'),
      'Password must not exceed 16 characters.',
    );
    expect(
      confirmMobilePassword('chosen-pass', 'different'),
      'Passwords do not match.',
    );
    expect(confirmMobilePassword('chosen-pass', 'chosen-pass'), isNull);
  });
  test(
    'center IDs normalize legacy numbers and never display long internal IDs',
    () {
      expect(centerIdLabel('DC-001', 'DC-'), 'DC-000001');
      expect(centerIdLabel('R-25', 'R-'), 'R-000025');
      expect(
        centerIdLabel('R-1792398969641134-0da53ab8227d4fc2', 'R-'),
        'Not assigned',
      );
      expect(sequentialCenterId('DC-', 999999), 'DC-999999');
      expect(
        () => sequentialCenterId('DC-', 1000000),
        throwsA(isA<BackendException>()),
      );
      expect(
        () => sequentialCenterId('R-', 0),
        throwsA(isA<BackendException>()),
      );
    },
  );
  test('next dialysis includes future sessions today and sorts actual stored sessions', () {
    final now = DateTime(2026, 10, 20, 8);
    SessionRecord session(String id, int day, int hour, SessionStatus status) =>
        SessionRecord(
          id: id,
          patientId: 'internal',
          start: DateTime(2026, 10, day, hour),
          room: 'Room 01',
          batch: 'Batch A',
          status: status,
        );
    final later = session('tomorrow', 21, 8, SessionStatus.pending);
    final today = session('today', 20, 10, SessionStatus.pending);
    expect(
      nextDialysisSession([
        later,
        today,
        session('past', 20, 7, SessionStatus.pending),
      ], now)?.id,
      'today',
    );
    expect(
      nextDialysisSession([
        session('finished', 20, 10, SessionStatus.completed),
      ], now),
      isNull,
    );
    expect(
      currentDialysisSession([today], now),
      isNull,
      reason: 'A future schedule is not an ongoing session.',
    );
    expect(
      currentDialysisSession([
        session('actual', 20, 7, SessionStatus.readyForPickUp),
      ], now)?.status,
      SessionStatus.readyForPickUp,
    );
  });
}

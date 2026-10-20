import 'package:core_shared/core_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PIN generation is numeric and verification is role/ID bound and case independent', () {
    final pins = List.generate(50, (_) => generateTemporaryPin());
    expect(pins.toSet().length, greaterThan(1));
    for (final pin in pins) {
      expect(pin, matches(RegExp(r'^\d{6}$')));
    }
    final pin = pins.first;
    final hash = pinInvitationId('patient', 'DC-001', pin);
    expect(hash, matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(hash, pinInvitationId('patient', 'dc-001', pin));
    expect(hash, isNot(pinInvitationId('relative', 'DC-001', pin)));
    expect(hash, isNot(pinInvitationId('patient', 'DC-002', pin)));
    expect(
      () => pinInvitationId('patient', 'DC-001', 'short'),
      throwsA(isA<BackendException>()),
    );
    expect(
      () => accountEmail('patient', 'person@example.com'),
      throwsA(isA<BackendException>()),
    );
    expect(
      accountEmail('patient', 'DC-001'),
      'dc-001@patient.dialycare.invalid',
    );
    expect(
      accountEmail('relative', 'REL-001'),
      'rel-001@relative.dialycare.invalid',
    );
  });
  test('all four lifecycle states survive model serialization', () {
    for (final status in MobileAccountStatus.values) {
      final account = MobileAccount(status: status);
      expect(MobileAccount.fromJson(account.toJson()).status, status);
    }
    expect(
      const MobileAccount(status: MobileAccountStatus.activationPending).label,
      'Activation Pending',
    );
  });
}

import 'package:dialycare_mobile/mobile_store.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authentication failures give recovery guidance without exposing provider details', () async {
    final store = MobileStore();
    addTearDown(store.dispose);
    for (final entry in {
      'invalid-email': 'ID',
      'weak-password': 'stronger password',
      'too-many-requests': 'wait',
      'network-request-failed': 'connection',
      'user-disabled': 'disabled',
    }.entries) {
      await store.action(
        () async => throw FirebaseAuthException(
          code: entry.key,
          message: 'PRIVATE PROVIDER DETAIL',
        ),
      );
      expect(store.error, contains(entry.value));
      expect(store.error, isNot(contains('PRIVATE PROVIDER DETAIL')));
      expect(store.busy, false);
    }
  });
}

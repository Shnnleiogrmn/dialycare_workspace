import 'dart:convert';

import 'package:core_shared/core_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'live streaming quota shape preserves diagnostics and stops retries',
    () async {
      var calls = 0;
      FirestoreFailure? diagnostic;
      final repo = FirestoreRepository(
        uid: () => 'fixture-uid',
        token: () async => 'secret-token',
        onFailure: (value) => diagnostic = value,
        client: MockClient((request) async {
          calls++;
          return http.Response(
            jsonEncode([
              {
                'error': {
                  'code': 429,
                  'message': 'Quota exceeded.',
                  'status': 'RESOURCE_EXHAUSTED',
                },
              },
            ]),
            429,
          );
        }),
      );
      await expectLater(
        repo.query('patients'),
        throwsA(isA<FirestoreFailure>()),
      );
      expect(diagnostic!.code, 'RESOURCE_EXHAUSTED');
      expect(diagnostic!.firebaseMessage, 'Quota exceeded.');
      expect(diagnostic!.resources, ['patients']);
      expect(diagnostic!.uid, 'fixture-uid');
      expect(diagnostic!.message, contains('usage limit'));
      expect(repo.quotaRetryAt, isNotNull);
      await expectLater(
        repo.get('users/fixture-uid'),
        throwsA(isA<BackendException>()),
      );
      expect(
        calls,
        1,
        reason: 'Quota backoff must prevent another network request.',
      );
      repo.close();
    },
  );

  test(
    'request traces redact invitation lookups and never contain request values',
    () async {
      FirestoreFailure? diagnostic;
      final repo = FirestoreRepository(
        uid: () => 'fixture',
        token: () async => 'private-token',
        onFailure: (value) => diagnostic = value,
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'error': {
                'status': 'INVALID_ARGUMENT',
                'message': 'Invalid request.',
              },
            }),
            400,
          ),
        ),
      );
      await expectLater(
        repo.request('POST', ':commit', {
          'writes': [
            {
              'update': repo.document('invitations/private-hash', {
                'password': 'never-log',
                'name': 'private-person',
              }),
            },
          ],
        }),
        throwsA(isA<FirestoreFailure>()),
      );
      expect(diagnostic!.resources, ['invitations/[redacted]']);
      expect(diagnostic!.code, 'INVALID_ARGUMENT');
      expect(diagnostic!.message, isNot(contains('Firestore request failed')));
      repo.close();
    },
  );
}

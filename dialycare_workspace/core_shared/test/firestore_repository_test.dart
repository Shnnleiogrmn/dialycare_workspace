import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:core_shared/core_shared.dart';

Map<String, dynamic> doc(String path, Map<String, dynamic> data) => {
  'name':
      'projects/dialycare-backend-3f0ed/databases/(default)/documents/$path',
  'fields': data.map((k, v) => MapEntry(k, FirestoreRepository.encode(v))),
};
void main() {
  test(
    'Staff and Admin require explicit active status before operational reads',
    () async {
      for (final role in ['staff', 'admin']) {
        for (final status in [null, 'disabled', 'active']) {
          final repo = FirestoreRepository(
            token: () async => 'token',
            uid: () => 'staff-uid',
            client: MockClient((r) async {
              expect(r.url.path.endsWith('/users/staff-uid'), true);
              return http.Response(
                jsonEncode(
                  doc('users/staff-uid', {
                    'role': role,
                    'disabled': false,
                    'accountStatus': ?status,
                  }),
                ),
                200,
              );
            }),
          );
          if (status == 'active') {
            expect((await repo.account())['role'], role);
          } else {
            await expectLater(
              repo.call('staffData'),
              throwsA(
                isA<BackendException>().having(
                  (e) => e.statusCode,
                  'status',
                  403,
                ),
              ),
            );
          }
          repo.close();
        }
      }
    },
  );

  test('Firestore typed values round trip nested models and timestamps', () {
    final value = {
      'id': 'TEST-001',
      'age': 40,
      'active': true,
      'optional': null,
      'items': [
        1,
        2.5,
        {'text': 'Test'},
      ],
    };
    expect(
      FirestoreRepository.decode(FirestoreRepository.encode(value) as Map),
      value,
    );
    expect(
      FirestoreRepository.decode({'timestampValue': '2026-10-17T00:00:00Z'}),
      '2026-10-17T00:00:00Z',
    );
  });
  test(
    'mobile queries only approved patient and recipient, with Firebase bearer',
    () async {
      final filters = <String, dynamic>{};
      final repo = FirestoreRepository(
        token: () async => 'firebase-id-token',
        uid: () => 'test-uid',
        client: MockClient((r) async {
          expect(r.headers['Authorization'], 'Bearer firebase-id-token');
          if (r.url.path.endsWith('/users/test-uid')) {
            return http.Response(
              jsonEncode(
                doc('users/test-uid', {
                  'role': 'patient',
                  'disabled': false,
                  'patientId': 'TEST-001',
                  'recipientId': 'TEST-001',
                }),
              ),
              200,
            );
          }
          if (r.url.path.endsWith('/patientProfiles/TEST-001')) {
            return http.Response(
              jsonEncode(
                doc('patientProfiles/TEST-001', {
                  'id': 'TEST-001',
                  'name': 'Test Patient',
                }),
              ),
              200,
            );
          }
          if (r.url.path.endsWith('/patientAccountProfiles/TEST-001')) {
            return http.Response(
              jsonEncode(
                doc('patientAccountProfiles/TEST-001', {
                  'id': 'TEST-001',
                  'contact': '0000000000',
                  'relativeName': 'Approved Relative',
                  'relationship': 'Other',
                }),
              ),
              200,
            );
          }
          expect(r.url.path.endsWith(':runQuery'), true);
          final query = jsonDecode(r.body)['structuredQuery'],
              collection = query['from'][0]['collectionId'];
          filters[collection] = query['where']['fieldFilter'];
          return http.Response('[]', 200);
        }),
      );
      final result = await repo.call('mobileData', {'role': 'patient'});
      expect(result['profile']['name'], 'Test Patient');
      expect(filters['sessions']['value'], {'stringValue': 'TEST-001'});
      expect(filters['notifications']['value'], {
        'stringValue': 'patient:TEST-001:TEST-001',
      });
      repo.close();
    },
  );
  test(
    'recipient read uses a server timestamp, never a forged local time',
    () async {
      final repo = FirestoreRepository(
        token: () async => 'token',
        uid: () => 'uid',
        client: MockClient((r) async {
          final body = jsonDecode(r.body);
          expect(body['writes'][0]['transform']['fieldTransforms'][0], {
            'fieldPath': 'readAt',
            'setToServerValue': 'REQUEST_TIME',
          });
          return http.Response('{}', 200);
        }),
      );
      await repo.call('readNotification', {'id': 'N-1'});
      repo.close();
    },
  );
  test(
    'unlinked accounts and role mismatch cannot load mobile clinical data',
    () async {
      var queries = 0;
      final repo = FirestoreRepository(
        token: () async => 'token',
        uid: () => 'uid',
        client: MockClient((r) async {
          queries++;
          return http.Response(
            jsonEncode(
              doc('users/uid', {
                'role': 'relative',
                'disabled': false,
                'patientId': 'TEST-001',
                'recipientId': 'R-001',
              }),
            ),
            200,
          );
        }),
      );
      await expectLater(
        repo.call('mobileData', {'role': 'patient'}),
        throwsA(isA<BackendException>()),
      );
      expect(queries, 1);
      repo.close();
    },
  );
  test(
    'Spark rejects privileged invitation and provider calls without network',
    () async {
      final repo = FirestoreRepository(
        token: () async => 'token',
        uid: () => 'uid',
        client: MockClient(
          (r) async => throw StateError('Must not call a Function'),
        ),
      );
      for (final action in [
        'register',
        'invite',
        'dispatch',
        'registerDevice',
      ]) {
        await expectLater(repo.call(action), throwsA(isA<BackendException>()));
      }
      repo.close();
    },
  );
}

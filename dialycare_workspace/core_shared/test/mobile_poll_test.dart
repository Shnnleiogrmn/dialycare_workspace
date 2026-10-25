import 'dart:convert';

import 'package:core_shared/core_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Mobile checks authorization before cache and receives changed sessions', () async {
    var version = 'first';
    var authorized = true;
    var queries = 0;
    Map<String, dynamic> doc(String path, Map<String, dynamic> fields) => {
      'name':
          'projects/dialycare-backend-3f0ed/databases/(default)/documents/$path',
      'fields': fields.map(
        (k, v) => MapEntry(k, FirestoreRepository.encode(v)),
      ),
    };
    final repo = FirestoreRepository(
      token: () async => 'fixture-token',
      uid: () => 'patient-uid',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/users/patient-uid')) {
          return http.Response(
            jsonEncode(
              doc('users/patient-uid', {
                'role': 'patient',
                'patientId': 'DC-001',
                'recipientId': 'DC-001',
                'disabled': !authorized,
              }),
            ),
            200,
          );
        }
        if (request.url.path.endsWith('/patientProfiles/DC-001')) {
          return http.Response(
            jsonEncode(
              doc('patientProfiles/DC-001', {
                'id': 'DC-001',
                'name': 'Verification',
                'syncVersion': version,
              }),
            ),
            200,
          );
        }
        if (request.url.path.endsWith(':runQuery')) {
          queries++;
          final collection = jsonDecode(
            request.body,
          )['structuredQuery']['from'][0]['collectionId'];
          if (collection == 'sessions' && version == 'second') {
            return http.Response(
              jsonEncode([
                {
                  'document': doc(
                    'sessions/S-1',
                    SessionRecord(
                      id: 'S-1',
                      patientId: 'DC-001',
                      start: DateTime(2026, 10, 20, 8),
                      room: 'Room 01',
                      batch: 'Batch A',
                      status: SessionStatus.readyForPickUp,
                    ).toJson(),
                  ),
                },
              ]),
              200,
            );
          }
          return http.Response('[{}]', 200);
        }
        return http.Response('{}', 200);
      }),
    );
    final first = await repo.loadMobile('patient');
    first['profile']['name'] = 'Caller mutation';
    final cached = await repo.loadMobile('patient', allowCached: true);
    expect(cached['profile']['name'], 'Verification');
    expect(
      queries,
      3,
      reason: 'Unchanged background refresh must not reload full histories.',
    );
    version = 'second';
    final changed = await repo.loadMobile('patient', allowCached: true);
    expect(queries, 5);
    expect(changed['sessions'][0]['status'], 'Ready for Pick Up');
    await repo.call('readNotification', {'id': 'own-notification'});
    await repo.loadMobile('patient', allowCached: true);
    expect(
      queries,
      7,
      reason: 'Read state must refresh immediately after acknowledgment.',
    );
    authorized = false;
    await expectLater(
      repo.loadMobile('patient', allowCached: true),
      throwsA(
        isA<BackendException>().having((e) => e.statusCode, 'status', 403),
      ),
    );
    expect(queries, 7);
    repo.close();
  });
}

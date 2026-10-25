import 'dart:convert';

import 'package:core_shared/core_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final rulesReady in [false, true]) {
    test(
      'existing operations survive while new registrations await ${rulesReady ? 'migration approval' : 'Rules publication'}',
      () async {
        const stamp = '2026-10-22T00:00:00Z';
        Map<String, dynamic> document(
          String path,
          Map<String, dynamic> value,
        ) => {
          'name':
              'projects/dialycare-backend-3f0ed/databases/(default)/documents/$path',
          'fields': value.map(
            (k, v) => MapEntry(k, FirestoreRepository.encode(v)),
          ),
        };
        var commits = 0;
        final repository = FirestoreRepository(
          token: () async => 'test-token',
          uid: () => 'staff',
          client: MockClient((request) async {
            if (request.url.path.endsWith('/users/staff')) {
              return http.Response(
                jsonEncode(
                  document('users/staff', {
                    'role': 'staff',
                    'disabled': false,
                    'accountStatus': 'active',
                  }),
                ),
                200,
              );
            }
            if (request.url.path.contains('/idCounters/patients-')) {
              return rulesReady
                  ? http.Response('{"error":{"status":"NOT_FOUND"}}', 404)
                  : http.Response(
                      '{"error":{"status":"PERMISSION_DENIED"}}',
                      403,
                    );
            }
            if (request.url.path.endsWith(':runQuery')) {
              final collection = jsonDecode(
                request.body,
              )['structuredQuery']['from'][0]['collectionId'];
              return http.Response(
                jsonEncode(
                  collection == 'patients'
                      ? [
                          {
                            'document': document('patients/legacy', {
                              'id': 'legacy',
                              'publicId': 'DC-000001',
                              'name': 'Synthetic legacy fixture',
                            }),
                          },
                        ]
                      : [],
                ),
                200,
              );
            }
            if (request.url.path.endsWith(':commit')) {
              commits++;
              final writes = jsonDecode(request.body)['writes'] as List;
              return http.Response(
                jsonEncode({
                  'commitTime': stamp,
                  'writeResults': [
                    for (final write in writes)
                      {
                        'updateTime': stamp,
                        'transformResults': [
                          for (final _
                              in write['updateTransforms'] as List? ?? [])
                            {'timestampValue': stamp},
                        ],
                      },
                  ],
                }),
                200,
              );
            }
            return http.Response('{"error":{"status":"NOT_FOUND"}}', 404);
          }),
        );
        addTearDown(repository.close);
        final bundle =
            (await repository.loadStaff())['bundle'] as Map<String, dynamic>;
        await repository.saveStaff(bundle);
        expect(commits, 1);
        (bundle['patients'] as List).add({
          'id': 'new-registration',
          'name': 'Synthetic new fixture',
        });
        await expectLater(
          repository.saveStaff(bundle),
          throwsA(
            isA<BackendException>().having(
              (e) => e.message,
              'message',
              contains(
                rulesReady
                    ? 'migration is approved and completed'
                    : 'reviewed yearly-ID Firestore Rules update',
              ),
            ),
          ),
        );
        expect(commits, 1);
      },
    );
  }
  test('an unissued legacy identity is never assigned a fabricated registration year', () async {
    Map<String, dynamic> document(String path, Map<String, dynamic> value) => {
      'name':
          'projects/dialycare-backend-3f0ed/databases/(default)/documents/$path',
      'fields': value.map((k, v) => MapEntry(k, FirestoreRepository.encode(v))),
    };
    var commits = 0;
    final repository = FirestoreRepository(
      token: () async => 'test-token',
      uid: () => 'staff',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/users/staff')) {
          return http.Response(
            jsonEncode(
              document('users/staff', {
                'role': 'staff',
                'disabled': false,
                'accountStatus': 'active',
              }),
            ),
            200,
          );
        }
        if (request.url.path.endsWith(':runQuery')) {
          final collection = jsonDecode(
            request.body,
          )['structuredQuery']['from'][0]['collectionId'];
          return http.Response(
            jsonEncode(
              collection == 'patients'
                  ? [
                      {
                        'document': document('patients/legacy-internal', {
                          'id': 'legacy-internal',
                          'name': 'Synthetic legacy fixture',
                        }),
                      },
                    ]
                  : [],
            ),
            200,
          );
        }
        if (request.url.path.endsWith(':commit')) commits++;
        return http.Response('{"error":{"status":"NOT_FOUND"}}', 404);
      }),
    );
    addTearDown(repository.close);
    final bundle =
        (await repository.loadStaff())['bundle'] as Map<String, dynamic>;
    await expectLater(
      repository.saveStaff(bundle),
      throwsA(
        isA<BackendException>().having(
          (e) => e.message,
          'message',
          contains('original registration'),
        ),
      ),
    );
    expect(commits, 0);
  });
  test(
    'Patient IDs contain the registration year and three-digit sequence',
    () {
      expect(yearlyPatientId(2026, 1), 'DP-2026-001');
      expect(yearlyPatientId(2027, 1), 'DP-2027-001');
      expect(yearlyPatientId(2026, 42), 'DP-2026-042');
      expect(yearlyPatientId(2026, 999), 'DP-2026-999');
      expect(patientIdYear('DP-2027-042'), 2027);
      expect(patientIdSequence('DP-2027-042'), 42);
      for (final n in [0, -1, 1000]) {
        expect(
          () => yearlyPatientId(2026, n),
          throwsA(isA<BackendException>()),
        );
      }
      expect(patientIdYear('DP-2026-000'), isNull);
    },
  );
  test(
    'new and legacy Patient IDs remain compatible with display and activation',
    () {
      for (final id in ['DP-2026-001', 'DC-000001', 'DC-001']) {
        expect(
          accountEmail('patient', id),
          '${id.toLowerCase()}@patient.dialycare.invalid',
        );
        expect(pinInvitationId('patient', id, '123456'), hasLength(64));
      }
      expect(centerIdLabel('DP-2026-001', 'DC-'), 'DP-2026-001');
      expect(centerIdLabel('DC-001', 'DC-'), 'DC-000001');
      expect(sequentialCenterId('R-', 1), 'R-000001');
    },
  );
}

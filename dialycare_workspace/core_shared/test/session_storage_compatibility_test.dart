import 'dart:convert';

import 'package:core_shared/core_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('equivalent stored date formats and integer progress do not rewrite care data', () async {
    const stamp = '2026-10-20T00:00:00Z';
    Map<String, dynamic> doc(String path, Map<String, dynamic> value) => {
      'name':
          'projects/dialycare-backend-3f0ed/databases/(default)/documents/$path',
      'fields': value.map((k, v) => MapEntry(k, FirestoreRepository.encode(v))),
      'updateTime': stamp,
    };
    final writes = <Map>[];
    final session = {
      'id': 'S',
      'patientId': 'P',
      'start': '2026-10-23T00:00:00Z',
      'room': 'Room 01',
      'batch': 'Batch A',
      'status': 'Pending',
      'progress': 0,
      'revision': 0,
      'expectedEnd': null,
      'plannedDurationMinutes': 240,
      'scheduleGroup': 'MWF',
    };
    final repo = FirestoreRepository(
      uid: () => 'staff',
      token: () async => 'test-token',
      client: MockClient((request) async {
        if (request.url.path.endsWith(':commit')) {
          writes.addAll(
            ((jsonDecode(request.body) as Map)['writes'] as List).cast<Map>(),
          );
          return http.Response(
            jsonEncode({
              'commitTime': stamp,
              'writeResults': [
                for (final _ in writes) {'updateTime': stamp},
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith(':runQuery')) {
          final collection = jsonDecode(
            request.body,
          )['structuredQuery']['from'][0]['collectionId'];
          final rows = switch (collection) {
            'patients' => [
              doc('patients/P', {
                'id': 'P',
                'publicId': 'DC-000001',
                'name': 'Fictional',
                'age': 40,
                'gender': 'Other',
                'contact': '',
                'recordStatus': 'active',
              }),
            ],
            'patientProfiles' => [
              doc('patientProfiles/P', {
                'id': 'P',
                'publicId': 'DC-000001',
                'name': 'Fictional',
                'syncVersion': 'stable',
              }),
            ],
            'sessions' => [doc('sessions/S', session)],
            _ => <Map<String, dynamic>>[],
          };
          return http.Response(
            jsonEncode(
              rows.isEmpty ? [{}] : rows.map((d) => {'document': d}).toList(),
            ),
            200,
          );
        }
        if (request.url.path.endsWith('/users/staff')) {
          return http.Response(
            jsonEncode(
              doc('users/staff', {
                'role': 'staff',
                'disabled': false,
                'accountStatus': 'active',
              }),
            ),
            200,
          );
        }
        if (request.url.path.endsWith('/clinical/state')) {
          return http.Response(
            jsonEncode(doc('clinical/state', {'revision': 0})),
            200,
          );
        }
        if (request.url.path.endsWith('/idCounters/center')) {
          return http.Response(
            jsonEncode(
              doc('idCounters/center', {
                'nextPatientNumber': 2,
                'nextRelativeNumber': 1,
              }),
            ),
            200,
          );
        }
        return http.Response('{"error":{"status":"NOT_FOUND"}}', 404);
      }),
    );
    addTearDown(repo.close);
    final bundle = (await repo.loadStaff())['bundle'] as Map<String, dynamic>;
    bundle['sessions'] = [
      SessionRecord.fromJson(Map<String, dynamic>.from(session)).toJson(),
    ];
    await repo.saveStaff(bundle);
    expect(
      writes.map((w) => (w['update'] as Map?)?['name']),
      everyElement(endsWith('/clinical/state')),
    );
  });
}

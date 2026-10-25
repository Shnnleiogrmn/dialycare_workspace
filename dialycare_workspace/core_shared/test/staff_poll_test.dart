import 'dart:convert';

import 'package:core_shared/core_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('unchanged Staff polling reuses care data but rechecks access and bindings', () async {
    var revision = '2026-10-20T00:00:00Z';
    final reads = <String, int>{};
    Map<String, dynamic> doc(String path, Map<String, dynamic> data) => {
      'name':
          'projects/dialycare-backend-3f0ed/databases/(default)/documents/$path',
      'fields': data.map(
        (key, value) => MapEntry(key, FirestoreRepository.encode(value)),
      ),
      'updateTime': revision,
    };
    final repo = FirestoreRepository(
      uid: () => 'staff',
      token: () async => 'fixture-token',
      client: MockClient((request) async {
        if (request.url.path.endsWith(':runQuery')) {
          final collection =
              jsonDecode(
                    request.body,
                  )['structuredQuery']['from'][0]['collectionId']
                  as String;
          reads.update(collection, (value) => value + 1, ifAbsent: () => 1);
          return http.Response('[{}]', 200);
        }
        if (request.url.path.endsWith('/users/staff')) {
          reads.update('account', (value) => value + 1, ifAbsent: () => 1);
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
            jsonEncode(doc('clinical/state', {'revision': 1})),
            200,
          );
        }
        return http.Response('{"error":{"status":"NOT_FOUND"}}', 404);
      }),
    );
    await repo.loadStaff();
    await repo.loadStaff(allowCached: true);
    expect(reads['patients'], 1);
    expect(reads['sessions'], 1);
    expect(reads['notifications'], 2);
    expect(reads['account'], 2);
    expect(reads['accountBindings'], 2);
    revision = '2026-10-20T00:01:00Z';
    await repo.loadStaff(allowCached: true);
    expect(
      reads['patients'],
      2,
      reason: 'A changed server revision must reload operational records.',
    );
    await repo.loadStaff();
    expect(
      reads['patients'],
      3,
      reason: 'Explicit full loads bypass the poll cache.',
    );
    repo.close();
  });
}

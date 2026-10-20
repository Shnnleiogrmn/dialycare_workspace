import 'dart:convert';
import 'dart:io';

import 'package:core_shared/core_shared.dart';
import 'package:dialycare_staff/models/patient.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final host = Platform.environment['FIRESTORE_EMULATOR_HOST'];
  test(
    'concurrent Staff creation cannot reuse IDs; refresh allocates the next permanent ID',
    () async {
      final tokens = jsonDecode(
        Platform.environment['DIALYCARE_TEST_AUTH_TOKENS']!,
      ) as Map;
      FirestoreRepository repository() => FirestoreRepository(
        token: () async => tokens['staff'] as String,
        uid: () => 'staff',
        project: 'demo-dialycare-spark',
        emulatorHost: host,
      );
      final a = repository(), b = repository();
      addTearDown(() {
        a.close();
        b.close();
      });
      final bundleA = (await a.loadStaff())['bundle'] as Map<String, dynamic>;
      final bundleB = (await b.loadStaff())['bundle'] as Map<String, dynamic>;
      final initialNumber = bundleA['nextPatientNumber'] as int;
      Map<String, dynamic> person(String id) => Patient(
        id: id,
        name: 'Concurrent verification',
        age: 30,
        gender: 'Other',
        contact: '',
      ).toJson();
      (bundleA['patients'] as List).add(person('ID-RACE-A'));
      (bundleB['patients'] as List).add(person('ID-RACE-B'));
      Future<BackendException?> save(
        FirestoreRepository repo,
        Map<String, dynamic> bundle,
      ) async {
        try {
          await repo.saveStaff(bundle);
          return null;
        } on BackendException catch (error) {
          return error;
        }
      }

      final outcomes = await Future.wait([save(a, bundleA), save(b, bundleB)]);
      expect(outcomes.where((v) => v == null).length, 1);
      expect(outcomes.whereType<BackendException>().length, 1);
      final retryId = outcomes[0] == null ? 'ID-RACE-B' : 'ID-RACE-A';
      final refreshed = (await a.loadStaff())['bundle'] as Map<String, dynamic>;
      expect(refreshed['nextPatientNumber'], initialNumber + 1);
      (refreshed['patients'] as List).add(person(retryId));
      await a.saveStaff(refreshed);
      final reopened = (await a.loadStaff())['bundle'] as Map<String, dynamic>;
      final records = (reopened['patients'] as List)
          .cast<Map>()
          .where((p) => ['ID-RACE-A', 'ID-RACE-B'].contains(p['id']))
          .toList();
      expect(records.map((p) => p['publicId']).toSet(), {
        sequentialCenterId('DC-', initialNumber),
        sequentialCenterId('DC-', initialNumber + 1),
      });
      final archived = records.first;
      archived['recordStatus'] = 'archived';
      archived['archivedAt'] = null;
      archived['archivedBy'] = null;
      await a.saveStaff(reopened);
      final afterArchive = (await a.loadStaff())['bundle'] as Map;
      expect(afterArchive['nextPatientNumber'], initialNumber + 2);
      expect(await a.get('publicIds/${archived['publicId']}'), isNotNull);
      await expectLater(
        a.request('POST', ':commit', {
          'writes': [
            {'delete': '${a.root}/publicIds/${archived['publicId']}'},
          ],
        }),
        throwsA(isA<BackendException>()),
      );
    },
    skip:
        host != '127.0.0.1:8089' ||
            Platform.environment['DIALYCARE_TEST_AUTH_TOKENS'] == null
        ? 'Requires the explicit local emulator harness.'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

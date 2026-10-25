import 'dart:convert';

import 'package:core_shared/core_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('concern validation, secure IDs and sequential lifecycle', () {
    final ids = List.generate(100, (_) => newConcernId());
    expect(ids.toSet(), hasLength(100));
    expect(
      ids.every((id) => RegExp(r'^FC-[A-F0-9]{20}$').hasMatch(id)),
      isTrue,
    );
    expect(concernTransition('Submitted', 'Under Review'), isTrue);
    expect(concernTransition('Under Review', 'Resolved'), isTrue);
    expect(concernTransition('Resolved', 'Closed'), isTrue);
    expect(concernTransition('Submitted', 'Resolved'), isFalse);
    expect(concernTransition('Closed', 'Submitted'), isFalse);
    for (final item in [
      ('', 'message'),
      ('subject', ' '),
      ('x' * 121, 'message'),
      ('subject', 'x' * 2001),
    ]) {
      expect(
        () => validateConcern('Feedback', item.$1, item.$2, 'Other'),
        throwsA(isA<BackendException>()),
      );
    }
    expect(
      () => validateConcern('Unknown', 'Subject', 'Message', 'Other'),
      throwsA(isA<BackendException>()),
    );
    expect(
      () => validateConcern('Feedback', 'Subject', 'Message', 'Unknown'),
      throwsA(isA<BackendException>()),
    );
  });
  for (final role in ['patient', 'relative']) {
    test(
      '$role submission derives identity from account and uses server timestamps',
      () async {
        Map<String, dynamic>? commit;
        final repo = FirestoreRepository(
          uid: () => 'owner',
          token: () async => 'fixture',
          client: MockClient((request) async {
            Map<String, dynamic> doc(Map<String, dynamic> d) => {
              'fields': d.map(
                (k, v) => MapEntry(k, FirestoreRepository.encode(v)),
              ),
            };
            if (request.url.path.endsWith('/users/owner')) {
              return http.Response(
                jsonEncode(
                  doc({
                    'role': role,
                    'patientId': 'P',
                    'recipientId': role == 'patient' ? 'P' : 'R',
                    'disabled': false,
                    'accountStatus': 'active',
                  }),
                ),
                200,
              );
            }
            if (request.url.path.endsWith('/patientProfiles/P')) {
              return http.Response(jsonEncode(doc({'name': 'Synthetic'})), 200);
            }
            if (request.url.path.endsWith(':commit')) {
              commit = jsonDecode(request.body);
              return http.Response('{}', 200);
            }
            throw StateError('Unexpected path');
          }),
        );
        addTearDown(repo.close);
        await FirestoreConcernService(
          repo,
        ).submit(newConcernId(), 'Feedback', ' Subject ', ' Message ', 'Other');
        final write = (commit!['writes'] as List).first as Map;
        final fields = FirestoreRepository.fields(
          write['update']['fields'] as Map,
        );
        expect(fields['submittedByUid'], 'owner');
        expect(fields['submittedByRole'], role);
        expect(fields['patientId'], 'P');
        expect(fields['relativeId'], role == 'relative' ? 'R' : null);
        expect(fields['subject'], 'Subject');
        expect(fields['message'], 'Message');
        expect(fields.containsKey('submittedByDisplayName'), isFalse);
        expect(write['currentDocument'], {'exists': false});
        expect(write['updateTransforms'], [
          {'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'},
          {'fieldPath': 'updatedAt', 'setToServerValue': 'REQUEST_TIME'},
        ]);
      },
    );
  }
  for (final archived in [false, true]) {
    test(
      'Staff reply preserves originals and handles archived=$archived safely',
      () async {
        Map<String, dynamic>? commit;
        final repo = FirestoreRepository(
          uid: () => 'staff',
          token: () async => 'fixture',
          client: MockClient((request) async {
            if (request.url.path.endsWith('/users/staff')) {
              return http.Response(
                jsonEncode({
                  'fields': {
                    'role': {'stringValue': 'staff'},
                    'disabled': {'booleanValue': false},
                    'accountStatus': {'stringValue': 'active'},
                  },
                }),
                200,
              );
            }
            if (request.url.path.endsWith('/patients/P')) {
              return http.Response(
                jsonEncode({
                  'fields': {
                    'recordStatus': {
                      'stringValue': archived ? 'archived' : 'active',
                    },
                  },
                }),
                200,
              );
            }
            commit = jsonDecode(request.body);
            return http.Response('{}', 200);
          }),
        );
        addTearDown(repo.close);
        final concern = FeedbackConcern({
          'concernId': newConcernId(),
          'status': 'Submitted',
          'revision': 0,
          'responseCount': 0,
          'lastResponseId': '',
          'submittedByRole': 'relative',
          'relativeId': 'R',
          'patientId': 'P',
          'message': 'Original private message',
        }, version: 'server-version');
        await FirestoreConcernService(repo)
            .update(concern, response: 'A safe response');
        final writes = commit!['writes'] as List;
        expect(writes, hasLength(archived ? 2 : 3));
        expect(writes[0]['currentDocument'], {'updateTime': 'server-version'});
        final fields = FirestoreRepository.fields(
          writes[0]['update']['fields'] as Map,
        );
        expect(fields.containsKey('message'), isFalse);
        expect(fields.containsKey('createdAt'), isFalse);
        expect(fields['status'], 'Under Review');
        expect(fields['responseCount'], 1);
        expect(
          writes[0]['updateMask']['fieldPaths'],
          isNot(contains('message')),
        );
        if (!archived) {
          final notice = FirestoreRepository.fields(
            writes[2]['update']['fields'] as Map,
          );
          expect(notice['recipientKey'], 'relative:R:P');
          expect(
            notice['message'],
            isNot(contains('Original private message')),
          );
          expect(notice['type'], 'concernUpdate');
        }
      },
    );
  }
}

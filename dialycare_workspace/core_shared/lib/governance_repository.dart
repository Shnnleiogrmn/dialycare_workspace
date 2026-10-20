import 'dart:math';

import 'backend_client.dart';
import 'firestore_repository.dart';
import 'governance.dart';

extension GovernanceRepository on FirestoreRepository {
  Map<String, dynamic> auditWrite(
    String action,
    String resourceType,
    String resourceId, {
    required String actorRole,
  }) {
    if (!auditLabels.containsKey(action)) {
      throw ArgumentError('Unknown audit action');
    }
    final id = List.generate(
      20,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return {
      'update': document('auditEvents/$id', {
        'actorUid': uid(),
        'actorRole': actorRole,
        'action': action,
        'resourceType': resourceType,
        'resourceId': resourceId,
        'outcome': 'success',
      }),
      'currentDocument': {'exists': false},
      'updateTransforms': [
        {'fieldPath': 'timestamp', 'setToServerValue': 'REQUEST_TIME'},
      ],
    };
  }

  Future<List<Map<String, dynamic>>> loadAuditEvents() async {
    final rows = await request('POST', ':runQuery', {
      'structuredQuery': {
        'from': [
          {'collectionId': 'auditEvents'},
        ],
        'orderBy': [
          {
            'field': {'fieldPath': 'timestamp'},
            'direction': 'DESCENDING',
          },
        ],
        'limit': 100,
      },
    }) as List;
    return [
      for (final row in rows)
        if ((row as Map)['document'] != null)
          data(Map<String, dynamic>.from(row['document'] as Map)),
    ];
  }

  Future<Map<String, dynamic>> loadCenterInformation() async {
    final doc = await get('settings/center');
    return doc == null
        ? {'name': 'DialyCare', 'contact': '', 'address': ''}
        : data(doc);
  }

  Future<void> saveCenterInformation(Map<String, dynamic> input) async {
    final owner = await account();
    if (owner['role'] != 'admin') {
      throw const BackendException(
        'Only an approved Center Admin can change center information.',
        403,
      );
    }
    final value = {
      for (final key in ['name', 'contact', 'address'])
        key: (input[key] as String? ?? '').trim(),
    };
    if (value['name']!.isEmpty ||
        value['name']!.length > 120 ||
        value['contact']!.length > 40 ||
        value['address']!.length > 240) {
      throw const BackendException('Enter valid center information.');
    }
    final current = await get('settings/center');
    await request('POST', ':commit', {
      'writes': [
        {
          'update': document('settings/center', {...value, 'updatedBy': uid()}),
          'currentDocument': current == null
              ? {'exists': false}
              : {'updateTime': current['updateTime']},
          'updateTransforms': [
            {'fieldPath': 'updatedAt', 'setToServerValue': 'REQUEST_TIME'},
          ],
        },
        auditWrite(
          'centerSettingsChanged',
          'settings',
          'center',
          actorRole: 'admin',
        ),
      ],
    });
  }
}

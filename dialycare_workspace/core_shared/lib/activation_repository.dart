import 'backend_client.dart';
import 'firestore_repository.dart';
import 'pin_activation.dart';
import 'governance.dart';
import 'governance_repository.dart';

/// Capstone PIN lookup and atomic claim remain subject to Firestore Rules.
/// No raw PIN, password or real email is stored in the care records.
extension ActivationRepository on FirestoreRepository {
  Future<Map<String, dynamic>> issueActivation({
    required String role,
    required String patientId,
    required String recipientId,
  }) async {
    accountEmail(role, recipientId);
    final actorRole = (await account())['role'] as String;
    final person = await get(
      role == 'patient' ? 'patients/$patientId' : 'relatives/$recipientId',
    );
    if (person == null) {
      throw const BackendException('Save the existing care record first.');
    }
    final publicId = data(person)['publicId'] as String? ?? recipientId;
    final careRecord = role == 'patient'
        ? person
        : await get('patients/$patientId');
    if (careRecord != null && data(careRecord)['recordStatus'] == 'archived') {
      throw const BackendException(
        'Restore the Patient before creating Mobile Access.',
      );
    }
    final existing = await get('accountBindings/${role}_$recipientId');
    if (existing != null &&
        (data(existing)['uid'] != null ||
            ![
              'notActivated',
              'activationPending',
            ].contains(data(existing)['accountStatus']))) {
      throw const BackendException(
        'This account is already activated. Use ID login or contact the center for trusted account recovery.',
      );
    }
    String? pin, code;
    for (var attempt = 0; attempt < 8; attempt++) {
      final candidate = generateTemporaryPin();
      final hash = pinInvitationId(role, publicId, candidate);
      if (await get('invitations/$hash') == null) {
        pin = candidate;
        code = hash;
        break;
      }
    }
    if (pin == null || code == null) {
      throw const BackendException(
        'Unable to generate fresh Mobile Access. Please try again.',
      );
    }
    final invitation = <String, dynamic>{
      'mode': 'temporaryPinV1',
      'role': role,
      'patientId': patientId,
      'recipientId': recipientId,
      'publicId': publicId,
      'patientPublicId': careRecord == null
          ? patientId
          : data(careRecord)['publicId'] ?? patientId,
      'displayName': data(person)['name'],
      'expiresAt': DateTime.now()
          .toUtc()
          .add(const Duration(hours: 24))
          .toIso8601String(),
      'issuedBy': uid(),
      'usedBy': null,
      'usedAt': null,
      'revoked': false,
    };
    final doc = document('invitations/$code', invitation);
    (doc['fields'] as Map)['expiresAt'] = {
      'timestampValue': invitation['expiresAt'],
    };
    final reservation = {
      'role': role,
      'patientId': patientId,
      'recipientId': recipientId,
      'uid': null,
      'accountStatus': 'activationPending',
      'activationId': code,
      'activatedAt': null,
    };
    await request('POST', ':commit', {
      'writes': [
        {
          'update': doc,
          'currentDocument': {'exists': false},
        },
        {
          'update': document(
            'accountBindings/${role}_$recipientId',
            reservation,
          ),
          'currentDocument': existing == null
              ? {'exists': false}
              : {'updateTime': existing['updateTime']},
        },
        auditWrite(
          existing == null || data(existing)['accountStatus'] == 'notActivated'
              ? 'mobileAccessCreated'
              : 'pinRegenerated',
          role,
          recipientId,
          actorRole: actorRole,
        ),
      ],
    });
    return {'pin': pin, 'expiresAt': invitation['expiresAt']};
  }

  Future<void> cancelMobileAccess({
    required String role,
    required String recipientId,
  }) async {
    final actorRole = (await account())['role'] as String;
    final doc = await get('accountBindings/${role}_$recipientId');
    if (doc == null ||
        data(doc)['uid'] != null ||
        data(doc)['accountStatus'] != 'activationPending') {
      throw const BackendException(
        'Only pending first-time Mobile Access can be cancelled.',
      );
    }
    await request('POST', ':commit', {
      'writes': [
        {
          'update': document('accountBindings/${role}_$recipientId', {
            'accountStatus': 'notActivated',
            'activationId': null,
          }),
          'updateMask': {
            'fieldPaths': ['accountStatus', 'activationId'],
          },
          'currentDocument': {'updateTime': doc['updateTime']},
        },
        auditWrite(
          'activationCancelled',
          role,
          recipientId,
          actorRole: actorRole,
        ),
      ],
    });
  }

  Future<Map<String, dynamic>> verifyActivation({
    required String code,
    required String role,
    required String recipientId,
  }) async {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(code)) {
      throw const BackendException(
        'Enter the Temporary PIN issued by your dialysis center.',
      );
    }
    Map<String, dynamic>? invitation;
    try {
      invitation = await get('invitations/$code');
    } on BackendException catch (e) {
      if (e.statusCode != 403 && e.statusCode != 404) rethrow;
      throw const BackendException(
        'Unable to verify this Temporary PIN. It may be incorrect, expired, cancelled, or already used. Please contact your dialysis center.',
      );
    }
    if (invitation == null) {
      throw const BackendException(
        'Unable to verify your ID and Temporary PIN. Please contact your dialysis center.',
      );
    }
    final value = data(invitation);
    if (value['mode'] != 'temporaryPinV1' ||
        value['role'] != role ||
        ![value['publicId'], value['recipientId']]
            .whereType<String>()
            .map((v) => v.toLowerCase())
            .contains(recipientId.trim().toLowerCase()) ||
        value['revoked'] == true ||
        value['usedBy'] != null ||
        !DateTime.parse(value['expiresAt'] as String).isAfter(DateTime.now())) {
      throw const BackendException(
        'Unable to verify your ID and Temporary PIN. Please contact your dialysis center.',
      );
    }
    return {...value, 'code': code, 'updateTime': invitation['updateTime']};
  }

  Future<void> claimActivation(
    Map<String, dynamic> preview, {
    required bool termsAccepted,
    required bool privacyAcknowledged,
  }) async {
    if (!termsAccepted || !privacyAcknowledged) {
      throw const BackendException(
        'Agree to the Terms of Use and acknowledge the Privacy Notice before activation.',
      );
    }
    final code = preview['code'] as String;
    final verified = await verifyActivation(
      code: code,
      role: preview['role'] as String,
      recipientId: (preview['publicId'] ?? preview['recipientId']) as String,
    );
    final account = {
      'role': verified['role'],
      'patientId': verified['patientId'],
      'recipientId': verified['recipientId'],
      'disabled': false,
      'accountStatus': 'active',
      'activationId': code,
    };
    final binding = {...account, 'uid': uid()}..remove('disabled');
    final stamp = [
      {'fieldPath': 'activatedAt', 'setToServerValue': 'REQUEST_TIME'},
    ];
    await request('POST', ':commit', {
      'writes': [
        {
          'update': document('users/${uid()}', account),
          'currentDocument': {'exists': false},
          'updateTransforms': stamp,
        },
        {
          'update': document(
            'accountBindings/${verified['role']}_${verified['recipientId']}',
            binding,
          ),
          'currentDocument': {'exists': true},
          'updateTransforms': stamp,
        },
        {
          'update': document('invitations/$code', {'usedBy': uid()}),
          'updateMask': {
            'fieldPaths': ['usedBy'],
          },
          'currentDocument': {'updateTime': verified['updateTime']},
          'updateTransforms': [
            {'fieldPath': 'usedAt', 'setToServerValue': 'REQUEST_TIME'},
          ],
        },
        {
          'update': document('policyAcceptances/${uid()}', {
            'uid': uid(),
            'role': verified['role'],
            'termsVersion': termsVersion,
            'privacyNoticeVersion': privacyNoticeVersion,
          }),
          'currentDocument': {'exists': false},
          'updateTransforms': [
            {
              'fieldPath': 'termsAcceptedAt',
              'setToServerValue': 'REQUEST_TIME',
            },
            {
              'fieldPath': 'privacyAcknowledgedAt',
              'setToServerValue': 'REQUEST_TIME',
            },
          ],
        },
        auditWrite(
          'accountActivated',
          verified['role'] as String,
          verified['recipientId'] as String,
          actorRole: verified['role'] as String,
        ),
      ],
    });
  }

  Future<void> setMobileAccess({
    required String role,
    required String recipientId,
    required bool enabled,
  }) async {
    final actorRole = (await account())['role'] as String;
    await request('POST', ':commit', {
      'writes': [
        {
          'update': document('accountBindings/${role}_$recipientId', {
            'accountStatus': enabled ? 'active' : 'disabled',
          }),
          'updateMask': {
            'fieldPaths': ['accountStatus'],
          },
          'currentDocument': {'exists': true},
        },
        auditWrite(
          enabled ? 'mobileAccessRestored' : 'mobileAccessDisabled',
          role,
          recipientId,
          actorRole: actorRole,
        ),
      ],
    });
  }
}

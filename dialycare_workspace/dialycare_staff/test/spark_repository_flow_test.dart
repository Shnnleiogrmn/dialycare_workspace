import 'dart:convert';
import 'dart:io';

import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:flutter_test/flutter_test.dart';
import 'package:core_shared/core_shared.dart';
import 'package:dialycare_staff/services/staff_store.dart';
import 'package:dialycare_staff/models/patient.dart';

// Test-only Auth REST transport: it rejects every non-loopback host.
class LocalAuthSession {
  LocalAuthSession(this.host) {
    if (host != '127.0.0.1:9099') {
      throw StateError('Only the local Auth emulator is allowed.');
    }
  }
  final String host;
  final client = http.Client();
  String? token, uid;
  Future<void> authenticate(
    String action,
    String email,
    String password,
  ) async {
    final response = await client.post(
      Uri.parse(
        'http://$host/identitytoolkit.googleapis.com/v1/accounts:$action?key=emulator-only-public-key',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );
    if (response.statusCode != 200) {
      throw const BackendException('Local Auth test request rejected.');
    }
    final value = jsonDecode(response.body) as Map;
    token = value['idToken'] as String;
    uid = value['localId'] as String;
  }

  Future<void> deleteHelper() async {
    await client.post(
      Uri.parse(
        'http://$host/identitytoolkit.googleapis.com/v1/accounts:delete?key=emulator-only-public-key',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': token}),
    );
  }

  void close() => client.close();
}

void main() {
  final host = Platform.environment['FIRESTORE_EMULATOR_HOST'];
  final authHost = Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'];
  final authTokens = Map<String, dynamic>.from(
    jsonDecode(Platform.environment['DIALYCARE_TEST_AUTH_TOKENS'] ?? '{}')
        as Map,
  );
  test(
    'real repository and StaffStore synchronize both roles, status, notifications, and read state',
    () async {
      const project = 'demo-dialycare-spark';
      final admin = FirestoreRepository(
        token: () async => 'owner',
        uid: () => 'admin',
        project: project,
        emulatorHost: host,
      );
      for (final entry in {
        'staff': {
          'role': 'staff',
          'disabled': false,
          'accountStatus': 'active',
        },
      }.entries) {
        await admin.request('POST', ':commit', {
          'writes': [
            {'update': admin.document('users/${entry.key}', entry.value)},
          ],
        });
      }
      final patientAuth = LocalAuthSession(authHost!),
          relativeAuth = LocalAuthSession(authHost);
      final staff = FirestoreRepository(
        token: () async => authTokens['staff'] as String?,
        uid: () => 'staff',
        project: project,
        emulatorHost: host,
      );
      final patient = FirestoreRepository(
        token: () async => patientAuth.token,
        uid: () => patientAuth.uid ?? '',
        project: project,
        emulatorHost: host,
      );
      final relative = FirestoreRepository(
        token: () async => relativeAuth.token,
        uid: () => relativeAuth.uid ?? '',
        project: project,
        emulatorHost: host,
      );
      FirestoreRepository repo(String role) => FirestoreRepository(
        token: () async => authTokens[role] as String?,
        uid: () => role,
        project: project,
        emulatorHost: host,
      );
      Future<Map<String, dynamic>> verifyPin(
        String role,
        String id,
        String pin,
      ) async {
        final helper = LocalAuthSession(authHost);
        final secret = base64Url
            .encode(List.generate(32, (_) => Random.secure().nextInt(256)))
            .replaceAll('=', '');
        await helper.authenticate(
          'signUp',
          'verify-${secret.toLowerCase()}@activation.dialycare.invalid',
          secret,
        );
        final reader = FirestoreRepository(
          token: () async => helper.token,
          uid: () => helper.uid!,
          project: project,
          emulatorHost: host,
        );
        try {
          return await reader.verifyActivation(
            code: pinInvitationId(role, id, pin),
            role: role,
            recipientId: id,
          );
        } finally {
          reader.close();
          await helper.deleteHelper();
          helper.close();
        }
      }

      addTearDown(() {
        patientAuth.close();
        relativeAuth.close();
      });
      final store = StaffStore(
        shared: true,
        readAuditEvents: staff.loadAuditEvents,
        readData: () async =>
            jsonEncode((await staff.call('staffData'))['bundle']),
        writeData: (value) async {
          await staff.call('staffSave', {'bundle': jsonDecode(value)});
        },
      );
      addTearDown(() {
        store.dispose();
        staff.close();
        patient.close();
        relative.close();
        admin.close();
      });
      await store.load();
      expect(store.loadError, isNull);
      expect(store.patients, isEmpty);
      const person = Patient(
        id: 'DC-001',
        name: 'Anna Marie',
        age: 40,
        gender: 'Other',
        contact: '',
        room: 'Test Room 01',
        maritalStatus: 'Married',
        philHealthNumber: '0000-0000-0000',
        heightCm: 168.5,
        weightKg: 62.2,
        mdrStatus: 'No',
        companions: [
          Companion(id: 'REL-001', name: 'Robert', relationship: 'Other'),
        ],
      );
      await store.savePatient(person);
      final createdPatient = staff.data((await staff.get('patients/DC-001'))!);
      expect(
        createdPatient['publicId'],
        yearlyPatientId(DateTime.now().year, 1),
      );
      for (final entry in {
        'maritalStatus': 'Married',
        'philHealthNumber': '0000-0000-0000',
        'heightCm': 168.5,
        'weightKg': 62.2,
        'mdrStatus': 'No',
      }.entries) {
        expect(createdPatient[entry.key], entry.value);
      }
      final reopenedRepository = repo('staff');
      final reopened = Patient.fromJson(
        Map<String, dynamic>.from(
          (await reopenedRepository.loadStaff())['bundle']['patients'][0]
              as Map,
        ),
      );
      expect(reopened.heightCm, 168.5);
      expect(reopened.weightKg, 62.2);
      expect(reopened.maritalStatus, 'Married');
      expect(reopened.philHealthNumber, '0000-0000-0000');
      expect(reopened.mdrStatus, 'No');
      reopenedRepository.close();
      expect(createdPatient['createdAt'], isNotNull);
      expect(createdPatient['updatedAt'], createdPatient['createdAt']);
      for (final entry in [
        ('patient', patient, patientAuth, 'DC-001'),
        ('relative', relative, relativeAuth, 'REL-001'),
      ]) {
        final role = entry.$1, id = entry.$4;
        final loginId = role == 'patient'
            ? yearlyPatientId(DateTime.now().year, 1)
            : 'R-000001';
        final first = await staff.issueActivation(
          role: role,
          patientId: 'DC-001',
          recipientId: id,
        );
        expect(first['pin'], matches(RegExp(r'^\d{6}$')));
        final second = await staff.issueActivation(
          role: role,
          patientId: 'DC-001',
          recipientId: id,
        );
        expect(second['pin'], isNot(first['pin']));
        await expectLater(
          verifyPin(role, loginId, first['pin'] as String),
          throwsA(isA<BackendException>()),
        );
        await staff.cancelMobileAccess(role: role, recipientId: id);
        await expectLater(
          verifyPin(role, loginId, second['pin'] as String),
          throwsA(isA<BackendException>()),
        );
        final invitation = await staff.issueActivation(
          role: role,
          patientId: 'DC-001',
          recipientId: id,
        );
        await store.refreshShared();
        final model = store.patientFor('DC-001');
        expect(
          (role == 'patient'
                  ? model.mobileAccount
                  : model.companions.single.mobileAccount)
              .activationExpiresAt,
          DateTime.parse(invitation['expiresAt'] as String),
        );
        expect(jsonEncode(model.toJson()), isNot(contains(invitation['pin'])));
        expect(
          role == 'patient'
              ? model.mobileAccount.label
              : model.companions.single.mobileAccount.label,
          'Activation Pending',
        );
        await expectLater(
          verifyPin(role, loginId, '000000'),
          throwsA(isA<BackendException>()),
        );
        final preview = await verifyPin(
          role,
          loginId,
          invitation['pin'] as String,
        );
        expect(
          preview['displayName'],
          role == 'patient' ? 'Anna Marie' : 'Robert',
        );
        expect(preview.containsKey('email'), false);
        expect(preview.containsKey('pin'), false);
        await entry.$3.authenticate(
          'signUp',
          accountEmail(role, loginId),
          'Owner-pass12!',
        );
        await expectLater(
          entry.$2.claimActivation(
            preview,
            termsAccepted: false,
            privacyAcknowledged: true,
          ),
          throwsA(isA<BackendException>()),
        );
        await entry.$2.claimActivation(
          preview,
          termsAccepted: true,
          privacyAcknowledged: true,
        );
        final accepted = staff.data(
          (await staff.get('policyAcceptances/${entry.$3.uid}'))!,
        );
        expect(accepted['termsVersion'], termsVersion);
        expect(accepted['privacyNoticeVersion'], privacyNoticeVersion);
        expect(accepted['termsAcceptedAt'], isNotNull);
        expect(accepted['termsAcceptedAt'], accepted['privacyAcknowledgedAt']);
        expect(accepted.keys, isNot(contains('ipAddress')));
        await expectLater(
          verifyPin(role, loginId, invitation['pin'] as String),
          throwsA(isA<BackendException>()),
        );
        entry.$3.token = null;
        await entry.$3.authenticate(
          'signInWithPassword',
          accountEmail(role, loginId),
          'Owner-pass12!',
        );
        expect(
          (await entry.$2.call('mobileData'))['profile']['patientName'],
          'Anna Marie',
        );
      }
      // Simulate a migrated Patient whose historical Auth alias is retained.
      // Only this disposable emulator identity is changed; UID/password stay put.
      final retainedUid = patientAuth.uid;
      final aliasUpdate = await patientAuth.client.post(
        Uri.parse(
          'http://$authHost/identitytoolkit.googleapis.com/v1/accounts:update?key=emulator-only-public-key',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': patientAuth.token,
          'email': accountEmail('patient', 'DC-000001'),
          'returnSecureToken': true,
        }),
      );
      expect(aliasUpdate.statusCode, 200);
      patientAuth.token = null;
      var compatibleLogin = false;
      for (final candidate in patientLoginIds(
        'patient',
        yearlyPatientId(DateTime.now().year, 1),
      )) {
        try {
          await patientAuth.authenticate(
            'signInWithPassword',
            accountEmail('patient', candidate),
            'Owner-pass12!',
          );
          compatibleLogin = true;
          break;
        } on BackendException {
          /* Try only the bounded aliases of this identity. */
        }
      }
      expect(compatibleLogin, isTrue);
      expect(patientAuth.uid, retainedUid);
      await store.refreshShared();
      await expectLater(
        patient.call('mobileData', {'role': 'relative'}),
        throwsA(isA<BackendException>()),
      );
      await expectLater(
        relative.call('mobileData', {'role': 'patient'}),
        throwsA(isA<BackendException>()),
      );
      expect(store.patientFor('DC-001').mobileAccount.label, 'Active');
      expect(
        store.patientFor('DC-001').companions.single.mobileAccount.label,
        'Active',
      );
      await staff.setMobileAccess(
        role: 'patient',
        recipientId: 'DC-001',
        enabled: false,
      );
      await expectLater(
        patient.call('mobileData'),
        throwsA(isA<BackendException>()),
      );
      expect(await staff.get('patients/DC-001'), isNotNull);
      await staff.setMobileAccess(
        role: 'patient',
        recipientId: 'DC-001',
        enabled: true,
      );

      await store.addSchedule(
        store.patientFor('DC-001'),
        DateTime(2026, 11, 1, 8),
        'Batch A',
      );
      final session = store.sessions.single;
      for (final r in [patient, relative]) {
        final data = await r.call('mobileData');
        expect(data['profile']['patientName'], 'Anna Marie');
        expect(data['sessions'].single['id'], session.id);
        expect(data['sessions'].single['room'], 'Test Room 01');
      }
      for (final status in [
        SessionStatus.inProgress,
        SessionStatus.paused,
        SessionStatus.inProgress,
        SessionStatus.completed,
        SessionStatus.readyForPickUp,
      ]) {
        final stale = status == SessionStatus.paused ? repo('staff') : null;
        final staleBundle = stale == null
            ? null
            : (await stale.loadStaff())['bundle'] as Map<String, dynamic>;
        await store.changeSessionStatus(
          session.id,
          status,
          reasonCode: status == SessionStatus.paused ? 'equipment' : null,
          note: status == SessionStatus.paused ? 'PRIVATE LOCAL NOTE' : '',
        );
        if (stale != null) {
          final raw = (staleBundle!['sessions'] as List).single as Map;
          raw['status'] = 'Completed';
          raw['revision'] = (raw['revision'] as int? ?? 0) + 1;
          raw['completedAt'] = DateTime.now().toUtc().toIso8601String();
          await expectLater(
            stale.saveStaff(staleBundle),
            throwsA(isA<BackendException>()),
          );
          stale.close();
        }
        for (final r in [patient, relative]) {
          expect(
            (await r.call('mobileData'))['sessions'].single['status'],
            status.label,
          );
        }
      }
      final privateHistory = await staff.sessionHistory(session.id);
      expect(
        privateHistory.any(
          (e) => e['type'] == 'PAUSE' && e['note'] == 'PRIVATE LOCAL NOTE',
        ),
        true,
      );
      for (final mobile in [patient, relative]) {
        await expectLater(
          mobile.query('sessionEvents', field: 'sessionId', equals: session.id),
          throwsA(isA<BackendException>()),
        );
        expect(
          jsonEncode(await mobile.call('mobileData'))
              .contains('PRIVATE LOCAL NOTE'),
          false,
        );
      }
      final pickups = store.deliveryHistory
          .where((n) => n.type.name == 'pickup')
          .length;
      expect(pickups, 2);
      await store.changeSessionStatus(session.id, SessionStatus.readyForPickUp);
      expect(
        store.deliveryHistory.where((n) => n.type.name == 'pickup').length,
        2,
      );
      final reminders = await store.sendReminder(
        session.id,
        recipientIds: {'DC-001', 'REL-001'},
      );
      expect(reminders.length, 2);
      expect(reminders.every((n) => n.status.name == 'available'), true);
      final notifications =
          (await patient.call('mobileData'))['notifications'] as List;
      final id = notifications.first['id'];
      await patient.call('readNotification', {'id': id});
      expect(
        ((await patient.call('mobileData'))['notifications'] as List)
            .firstWhere((n) => n['id'] == id)['readAt'],
        isNotNull,
      );
      await store.savePatient(
        person,
      ); // Staff saves must preserve recipient read state.
      expect(
        staff.data((await staff.get('patients/DC-001'))!)['updatedAt'],
        createdPatient['updatedAt'],
      );
      for (final entry in [
        ('patient', patient, 'DC-001'),
        ('relative', relative, 'REL-001'),
      ]) {
        await staff.setMobileAccess(
          role: entry.$1,
          recipientId: entry.$3,
          enabled: false,
        );
        await expectLater(
          entry.$2.call('mobileData'),
          throwsA(isA<BackendException>()),
        );
        expect(await staff.get('patients/DC-001'), isNotNull);
        expect(await staff.get('sessions/${session.id}'), isNotNull);
        expect(await staff.get('notifications/$id'), isNotNull);
        await staff.setMobileAccess(
          role: entry.$1,
          recipientId: entry.$3,
          enabled: true,
        );
        expect(
          (await entry.$2.call('mobileData'))['sessions'].single['status'],
          SessionStatus.readyForPickUp.label,
        );
      }
      expect(
        ((await patient.call('mobileData'))['notifications'] as List)
            .firstWhere((n) => n['id'] == id)['readAt'],
        isNotNull,
      );
      await expectLater(
        relative.get('patientProfiles/UNRELATED'),
        throwsA(isA<BackendException>()),
      );
      // Exercise the real concern REST repository under Auth/Firestore Rules.
      final patientConcerns = FirestoreConcernService(patient);
      final relativeConcerns = FirestoreConcernService(relative);
      final staffConcerns = FirestoreConcernService(staff);
      final patientConcernId = newConcernId(),
          relativeConcernId = newConcernId();
      await patientConcerns.submit(
        patientConcernId,
        'Schedule Concern',
        'Synthetic schedule question',
        'First line\nSecond line',
        'Schedule',
      );
      await relativeConcerns.submit(
        relativeConcernId,
        'Feedback',
        'Synthetic feedback',
        'Original Relative message',
        'Other',
      );
      expect((await patientConcerns.list()).map((c) => c.id), [
        patientConcernId,
      ]);
      expect((await relativeConcerns.list()).map((c) => c.id), [
        relativeConcernId,
      ]);
      await expectLater(
        relative.get('feedbackConcerns/$patientConcernId'),
        throwsA(isA<BackendException>()),
      );
      var ticket = (await staffConcerns.list()).firstWhere(
        (c) => c.id == patientConcernId,
      );
      expect(ticket.submitter, 'Anna Marie');
      await staffConcerns.update(
        ticket,
        response: 'Your schedule has been reviewed.',
      );
      await expectLater(
        staffConcerns.update(ticket, response: 'Stale reply'),
        throwsA(isA<BackendException>()),
      );
      ticket = (await staffConcerns.list()).firstWhere(
        (c) => c.id == patientConcernId,
      );
      await staffConcerns.update(
        ticket,
        response: 'A second response is retained.',
      );
      ticket = (await staffConcerns.list()).firstWhere(
        (c) => c.id == patientConcernId,
      );
      expect(
        (await patientConcerns.responses(ticket)).map((r) => r['message']),
        ['Your schedule has been reviewed.', 'A second response is retained.'],
      );
      await expectLater(
        relativeConcerns.responses(ticket),
        throwsA(isA<BackendException>()),
      );
      await staffConcerns.update(ticket, status: 'Resolved');
      ticket = (await staffConcerns.list()).firstWhere(
        (c) => c.id == patientConcernId,
      );
      expect(ticket.values['resolvedAt'], isNotNull);
      await staffConcerns.update(ticket, status: 'Closed');
      final own = (await patientConcerns.list()).single;
      expect(own.status, 'Closed');
      expect(own.values['message'], 'First line\nSecond line');
      expect(own.values['closedAt'], isNotNull);
      expect(
        ((await patient.loadMobile('patient'))['notifications'] as List).where(
          (n) => n['type'] == 'concernUpdate',
        ),
        hasLength(4),
      );
      var relativeTicket = (await staffConcerns.list()).firstWhere(
        (c) => c.id == relativeConcernId,
      );
      await staffConcerns.update(
        relativeTicket,
        response: 'Relative feedback reviewed.',
      );
      relativeTicket = (await staffConcerns.list()).firstWhere(
        (c) => c.id == relativeConcernId,
      );
      await staffConcerns.update(relativeTicket, status: 'Resolved');
      expect(
        (await relativeConcerns.responses(
          (await relativeConcerns.list()).single,
        )).single['message'],
        'Relative feedback reviewed.',
      );
      final staffHistory = await FirestoreHistoryService(staff).list();
      final patientHistory = await FirestoreHistoryService(patient).list();
      final relativeHistory = await FirestoreHistoryService(relative).list();
      for (final history in [staffHistory, patientHistory, relativeHistory]) {
        expect(history.any((e) => e.category == 'Sessions'), isTrue);
        expect(history.any((e) => e.category == 'Schedule Changes'), isTrue);
        expect(history.any((e) => e.category == 'Feedback & Concerns'), isTrue);
        expect(
          history.every((e) => !e.details.contains('PRIVATE LOCAL NOTE')),
          isTrue,
        );
        expect(
          history.every(
            (e) => e.patient.contains(yearlyPatientId(DateTime.now().year, 1)),
          ),
          isTrue,
        );
      }
      expect(
        patientHistory.any((e) => e.title == 'Synthetic feedback'),
        isFalse,
      );
      expect(
        relativeHistory.any((e) => e.title == 'Synthetic schedule question'),
        isFalse,
      );
      await expectLater(
        relative.query(
          'scheduleHistory',
          field: 'patientId',
          equals: 'UNRELATED',
        ),
        throwsA(isA<BackendException>()),
      );
      expect(
        (await staff.query(
          'notifications',
          field: 'recipientKey',
          equals: 'staff:all',
        )).length,
        2,
      );
      final relativeProfile =
          (await relative.loadMobile('relative'))['profile'] as Map;
      expect(relativeProfile['accountId'], 'R-000001');
      expect(
        relativeProfile['patientId'],
        yearlyPatientId(DateTime.now().year, 1),
      );
      for (final field in [
        'philHealthNumber',
        'heightCm',
        'weightKg',
        'mdrStatus',
        'medicalNotes',
      ]) {
        expect(relativeProfile.containsKey(field), false);
      }
      await expectLater(
        relative.get('patientAccountProfiles/DC-001'),
        throwsA(isA<BackendException>()),
      );
      await expectLater(
        relative.get('patients/DC-001'),
        throwsA(isA<BackendException>()),
      );
      await expectLater(
        relative.request('POST', ':commit', {
          'writes': [
            {
              'update': relative.document('users/${relative.uid()}', {
                'role': 'staff',
              }),
            },
          ],
        }),
        throwsA(isA<BackendException>()),
      );
      // Concern updates are independent commits; refresh the displayed inbox
      // before marking all currently loaded notifications as read.
      await store.refreshShared();
      final stale = repo('staff');
      addTearDown(stale.close);
      final old = await stale.call('staffData');
      await store.markAllRead();
      final refreshed = await staff.call('staffData');
      expect(
        (refreshed['bundle']['deliveryHistory'] as List).every(
          (n) => n['read'] == true,
        ),
        true,
      );
      await expectLater(
        stale.call('staffSave', {'bundle': old['bundle']}),
        throwsA(isA<BackendException>()),
      );
      final replacement = Patient.fromJson({
        ...store.patientFor('DC-001').toJson(),
        'name': 'Updated Anna Marie',
        'companions': [
          {...person.companions.single.toJson(), 'name': 'Replacement Robert'},
        ],
      });
      await store.savePatient(replacement);
      final editedPatient = staff.data((await staff.get('patients/DC-001'))!);
      expect(editedPatient['createdAt'], createdPatient['createdAt']);
      expect(editedPatient['updatedAt'], isNot(createdPatient['updatedAt']));
      expect(store.patientFor('DC-001').companions.single.id, isNot('REL-001'));
      expect(
        store.patientFor('DC-001').companions.single.mobileAccount.label,
        'Not Activated',
      );
      await expectLater(
        relative.call('mobileData'),
        throwsA(isA<BackendException>()),
      );
      expect(await staff.get('relatives/REL-001'), isNotNull);
      expect(
        staff.data(
          (await staff.get('patientRelativeLinks/REL-001_DC-001'))!,
        )['active'],
        false,
      );
      final historyCount = store.sessions
          .where((s) => s.patientId == 'DC-001')
          .length;
      await store.setPatientArchived('DC-001', true);
      await store.refreshShared();
      expect(store.patientFor('DC-001').archived, isTrue);
      expect(store.patientFor('DC-001').archivedAt, isNotNull);
      expect(store.patientFor('DC-001').archivedBy, 'staff');
      final archivedBefore = staff.data((await staff.get('patients/DC-001'))!);
      await store.savePatient(store.patientFor('DC-001'));
      final archivedAfter = staff.data((await staff.get('patients/DC-001'))!);
      expect(archivedAfter['archivedAt'], archivedBefore['archivedAt']);
      expect(archivedAfter['updatedAt'], archivedBefore['updatedAt']);

      expect(store.activePatients.any((p) => p.id == 'DC-001'), isFalse);
      expect(
        store.sessions.where((s) => s.patientId == 'DC-001').length,
        historyCount,
      );
      await expectLater(
        store.addSchedule(
          store.patientFor('DC-001'),
          DateTime(2026, 12, 1),
          'Batch A',
        ),
        throwsStateError,
      );
      await store.setPatientArchived('DC-001', false);
      await store.refreshShared();
      expect(store.patientFor('DC-001').archived, isFalse);
      expect(
        store.sessions.where((s) => s.patientId == 'DC-001').length,
        historyCount,
      );
      await expectLater(
        staff.saveCenterInformation({'name': 'Fictional center'}),
        throwsA(isA<BackendException>()),
      );
      final adminAuth = LocalAuthSession(authHost);
      await adminAuth.authenticate(
        'signUp',
        'center-admin-test@example.invalid',
        'Fictional-admin-test-password!',
      );
      final centerAdmin = FirestoreRepository(
        token: () async => adminAuth.token,
        uid: () => adminAuth.uid!,
        project: project,
        emulatorHost: host,
      );
      addTearDown(() {
        adminAuth.close();
        centerAdmin.close();
      });
      await admin.request('POST', ':commit', {
        'writes': [
          {
            'update': admin.document('users/${adminAuth.uid}', {
              'role': 'admin',
              'disabled': false,
              'accountStatus': 'active',
            }),
          },
        ],
      });
      await centerAdmin.saveCenterInformation({
        'name': 'Fictional Development Center',
        'contact': '',
        'address': '',
      });
      await store.refreshShared();
      expect(store.centerInformation['name'], 'Fictional Development Center');
      final settings = staff.data((await staff.get('settings/center'))!);
      expect(settings['updatedBy'], adminAuth.uid);
      expect(settings['updatedAt'], isNotNull);
      final activity = await staff.loadAuditEvents();
      await store.refreshAuditActivity();
      expect(store.auditEvents, activity);
      for (final action in [
        'patientCreated',
        'accountActivated',
        'mobileAccessCreated',
        'pinRegenerated',
        'activationCancelled',
        'patientArchived',
        'patientRestored',
        'centerSettingsChanged',
      ]) {
        expect(
          activity.any((e) => e['action'] == action),
          isTrue,
          reason: action,
        );
      }
      expect(
        activity.every((e) => e['timestamp'] != null && e['actorUid'] != null),
        isTrue,
      );
      await expectLater(
        patient.loadAuditEvents(),
        throwsA(isA<BackendException>()),
      );
      await expectLater(
        relative.loadAuditEvents(),
        throwsA(isA<BackendException>()),
      );
      final outbox = await http.get(
        Uri.parse('http://$authHost/emulator/v1/projects/$project/oobCodes'),
      );
      // The fixture's retained-alias change generates a recovery-email entry.
      // Activation itself must never send verification or password-reset email.
      final codes = (jsonDecode(outbox.body)['oobCodes'] as List?) ?? [];
      expect(codes.length, 1);
      expect((codes.single as Map)['requestType'], 'RECOVER_EMAIL');
      await expectLater(
        relative.call('mobileData'),
        throwsA(isA<BackendException>()),
      );
    },
    skip: host == null || authHost == null
        ? 'Run with the local Auth and Firestore emulators; this is not a production Firebase test.'
        : false,
  );
}

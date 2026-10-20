import 'dart:convert';
import 'dart:io';

import 'package:core_shared/core_shared.dart';
import 'package:dialycare_staff/models/patient.dart';
import 'package:dialycare_staff/services/staff_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = Platform.environment['DIALYCARE_LIVE_FIXTURE'];
  test(
    'explicit live StaffStore and Mobile repository workflow',
    () async {
      final fixture = jsonDecode(raw!) as Map;
      final pid = fixture['patientId'] as String,
          rid = fixture['relativeId'] as String;
      FirestoreRepository repository(String role) => FirestoreRepository(
        token: () async => fixture[role]['idToken'] as String,
        uid: () => fixture[role]['localId'] as String,
      );
      final staff = repository('staff'),
          helper = repository('helper'),
          patient = repository('patient'),
          relative = repository('relative');
      addTearDown(() {
        for (final repo in [staff, helper, patient, relative]) {
          repo.close();
        }
      });
      if (fixture['phase'] == 'relogin') {
        for (final role in ['patient', 'relative']) {
          final data = await (role == 'patient' ? patient : relative)
              .loadMobile(role);
          expect(data['profile']['patientId'], fixture['patientPublicId']);
          expect(
            data['profile']['accountId'],
            fixture[role == 'patient' ? 'patientPublicId' : 'relativePublicId'],
          );
          final sessions = (data['sessions'] as List)
              .map(
                (s) =>
                    SessionRecord.fromJson(Map<String, dynamic>.from(s as Map)),
              )
              .toList();
          expect(sessions.every((s) => s.patientId == pid), true);
          expect(
            sessions.any((s) => s.status == SessionStatus.readyForPickUp),
            true,
          );
          expect(nextDialysisSession(sessions, DateTime.now()), isNotNull);
          final ended = sessions.firstWhere(
            (s) => s.status == SessionStatus.endedEarly,
          );
          expect(
            ended.elapsedAt(DateTime.now()),
            ended.elapsedAt(DateTime.now().add(const Duration(days: 10))),
          );
        }
        stdout.writeln('LIVE_NORMAL_LOGIN_DATA_VERIFIED');
        return;
      }
      late final StaffStore store;
      store = StaffStore(
        shared: true,
        readSessionEvents: staff.sessionHistory,
        issueActivation: (role, patientId, recipientId) =>
            staff.issueActivation(
              role: role,
              patientId: patientId,
              recipientId: recipientId,
            ),
        readData: () async => jsonEncode((await staff.loadStaff())['bundle']),
        writeData: (body) async {
          final result = await staff.saveStaff(
            Map<String, dynamic>.from(jsonDecode(body) as Map),
          );
          store.workspaceVersion = result['workspaceVersion'] as String?;
          store.sessions = (result['sessions'] as List)
              .map(
                (s) =>
                    SessionRecord.fromJson(Map<String, dynamic>.from(s as Map)),
              )
              .toList();
        },
      );
      addTearDown(store.dispose);
      await store.load();
      expect(store.loadError, isNull);
      if (['pause', 'resume'].contains(fixture['phase'])) {
        final current = store.sessions.firstWhere((s) => s.patientId == pid);
        if (fixture['phase'] == 'pause') {
          await store.changeSessionStatus(
            current.id,
            SessionStatus.paused,
            reasonCode: 'equipment',
            note: 'PRIVATE EQUIPMENT TEST NOTE',
            expectedRevision: current.revision,
          );
        } else {
          expect(current.status, SessionStatus.paused);
          expect(
            current.elapsedAt(DateTime.now()),
            current.elapsedAt(DateTime.now().add(const Duration(days: 1))),
          );
          final history = await store.sessionHistory(current.id);
          expect(
            history.any(
              (e) =>
                  e['reasonCode'] == 'equipment' &&
                  e['note'] == 'PRIVATE EQUIPMENT TEST NOTE',
            ),
            true,
          );
          await store.changeSessionStatus(
            current.id,
            SessionStatus.inProgress,
            expectedRevision: current.revision,
          );
          await store.changeSessionStatus(
            current.id,
            SessionStatus.paused,
            reasonCode: 'temporary',
          );
          await store.changeSessionStatus(current.id, SessionStatus.inProgress);
        }
        final saved = store.sessions.firstWhere((s) => s.id == current.id);
        for (final role in ['patient', 'relative']) {
          final mobile = role == 'patient' ? patient : relative;
          final data = await mobile.loadMobile(role);
          final restored = SessionRecord.fromJson(
            Map<String, dynamic>.from(
              (data['sessions'] as List).firstWhere(
                (s) => s['id'] == current.id,
              ) as Map,
            ),
          );
          expect(restored.status, saved.status);
          expect(restored.pauseIntervals.length, saved.pauseIntervals.length);
          if (saved.status == SessionStatus.paused) {
            expect(
              restored.elapsedAt(DateTime.now().add(const Duration(days: 2))),
              saved.elapsedAt(DateTime.now()),
            );
          }
          expect(
            jsonEncode(data).contains('PRIVATE EQUIPMENT TEST NOTE'),
            false,
          );
          await expectLater(
            mobile.get('sessionEvents/${current.id}_2'),
            throwsA(isA<BackendException>()),
          );
          await expectLater(
            mobile.query(
              'sessionEvents',
              field: 'sessionId',
              equals: current.id,
            ),
            throwsA(isA<BackendException>()),
          );
          await expectLater(
            mobile.request('PATCH', '/sessions/${current.id}', {
              'fields': {
                'status': {'stringValue': 'Completed'},
              },
            }),
            throwsA(isA<BackendException>()),
          );
        }
        stdout.writeln(
          fixture['phase'] == 'pause'
              ? 'LIVE_PAUSE_STAFF_FIRESTORE_PATIENT_RELATIVE_FROZEN_PRIVATE_VERIFIED'
              : 'LIVE_RESTART_RESUME_MULTIPLE_PAUSES_SYNCHRONIZED_VERIFIED',
        );
        return;
      }
      if (fixture['phase'] == null) {
        await store.savePatient(
          Patient(
            id: pid,
            publicId: fixture['patientPublicId'] as String,
            name: 'DialyCare verification patient',
            age: 30,
            gender: 'Other',
            contact: '0000000000',
            room: 'Verification Room',
            maritalStatus: 'Married',
            philHealthNumber: '0000-0000-0000',
            heightCm: 168.5,
            weightKg: 62.2,
            mdrStatus: 'No',
            companions: [
              Companion(
                id: rid,
                publicId: fixture['relativePublicId'] as String,
                name: 'DialyCare verification relative',
                relationship: 'Other',
                contact: '0000000000',
              ),
            ],
          ),
        );
        await store.refreshShared();
        expect(store.loadError, isNull);
        final saved = store.patientFor(pid);
        expect(saved.displayId, fixture['patientPublicId']);
        expect(saved.companions.single.displayId, fixture['relativePublicId']);
        expect(saved.maritalStatus, 'Married');
        expect(saved.philHealthNumber, '0000-0000-0000');
        expect(saved.heightCm, 168.5);
        expect(saved.weightKg, 62.2);
        expect(saved.mdrStatus, 'No');
        for (final role in ['patient', 'relative']) {
          final id = role == 'patient' ? pid : rid;
          final publicId =
              fixture[role == 'patient'
                      ? 'patientPublicId'
                      : 'relativePublicId']
                  as String;
          final issued = await store.issueActivation!(role, pid, id);
          final preview = await helper.verifyActivation(
            code: pinInvitationId(role, publicId, issued['pin'] as String),
            role: role,
            recipientId: publicId,
          );
          final mobile = role == 'patient' ? patient : relative;
          await mobile.claimActivation(
            preview,
            termsAccepted: true,
            privacyAcknowledged: true,
          );
          final data = await mobile.loadMobile(role);
          expect(data['profile']['patientId'], fixture['patientPublicId']);
          expect(data['profile']['accountId'], publicId);
          for (final field in [
            'philHealthNumber',
            'mdrStatus',
            'heightCm',
            'weightKg',
            'medicalNotes',
          ]) {
            expect((data['profile'] as Map).containsKey(field), false);
          }
          await expectLater(
            mobile.get('patients/$pid'),
            throwsA(
              isA<BackendException>().having(
                (e) => e.statusCode,
                'status',
                403,
              ),
            ),
          );
          await expectLater(
            mobile.get('patientProfiles/DC-001'),
            throwsA(
              isA<BackendException>().having(
                (e) => e.statusCode,
                'status',
                403,
              ),
            ),
          );
        }
        await expectLater(
          relative.get('patientAccountProfiles/$pid'),
          throwsA(isA<BackendException>()),
        );
        final now = DateTime.now();
        await store.addSchedule(
          store.patientFor(pid),
          DateTime(now.year, now.month, now.day, 0),
          'Batch A',
        );
        final session = store.sessions.firstWhere((s) => s.patientId == pid);
        await store.changeSessionStatus(session.id, SessionStatus.inProgress);
        stdout.writeln('LIVE_ACTIVE_SESSION_SAVED_BEFORE_PROCESS_EXIT');
        return;
      }
      final session = store.sessions.firstWhere((s) => s.patientId == pid);
      final started = store.sessions
          .firstWhere((s) => s.id == session.id)
          .actualStartedAt!;
      expect(
        (await staff.get(
          'sessions/${session.id}',
        ))!['fields']['actualStartedAt']['timestampValue'],
        isNotNull,
      );
      // Recreate clients from persisted Firestore data, as an application restart does.
      final reopenedStaff = repository('staff'),
          reopenedPatient = repository('patient'),
          reopenedRelative = repository('relative');
      addTearDown(() {
        reopenedStaff.close();
        reopenedPatient.close();
        reopenedRelative.close();
      });
      final reopenedBundle = (await reopenedStaff.loadStaff())['bundle'] as Map;
      final reopenedSession = SessionRecord.fromJson(
        Map<String, dynamic>.from(
          (reopenedBundle['sessions'] as List).firstWhere(
            (s) => s['id'] == session.id,
          ) as Map,
        ),
      );
      expect(reopenedSession.actualStartedAt!.isAtSameMomentAs(started), true);
      final simulatedLater = started.add(const Duration(hours: 4, minutes: 18));
      expect(
        reopenedSession.elapsedAt(simulatedLater),
        const Duration(hours: 4, minutes: 18) -
            reopenedSession.totalPausedAt(simulatedLater),
      );
      expect(reopenedSession.progressAt(simulatedLater), 1);
      expect(reopenedSession.status, SessionStatus.inProgress);
      for (final entry in [
        (reopenedPatient, 'patient'),
        (reopenedRelative, 'relative'),
      ]) {
        final restored = SessionRecord.fromJson(
          Map<String, dynamic>.from(
            ((await entry.$1.loadMobile(entry.$2))['sessions'] as List).first
                as Map,
          ),
        );
        expect(restored.actualStartedAt!.isAtSameMomentAs(started), true);
        expect(
          restored.elapsedAt(simulatedLater),
          const Duration(hours: 4, minutes: 18) -
              reopenedSession.totalPausedAt(simulatedLater),
        );
      }
      stdout.writeln('LIVE_FIRESTORE_RESTART_TIMER_AND_OVERDUE_VERIFIED');
      expect(
        (await patient.loadMobile('patient'))['sessions'][0]['status'],
        'In Progress',
      );
      await store.changeSessionStatus(session.id, SessionStatus.completed);
      final completed = store.sessions.firstWhere((s) => s.id == session.id);
      expect(completed.completedAt, isNotNull);
      expect(
        (await staff.get(
          'sessions/${session.id}',
        ))!['fields']['completedAt']['timestampValue'],
        isNotNull,
      );
      final frozen = completed.elapsedAt(DateTime.now());
      for (final entry in [
        (reopenedPatient, 'patient'),
        (reopenedRelative, 'relative'),
      ]) {
        final restored = SessionRecord.fromJson(
          Map<String, dynamic>.from(
            ((await entry.$1.loadMobile(entry.$2))['sessions'] as List).first
                as Map,
          ),
        );
        expect(
          restored.elapsedAt(DateTime.now().add(const Duration(days: 1))),
          frozen,
        );
      }
      stdout.writeln('LIVE_COMPLETED_DURATION_PERSISTS_AND_STAYS_FROZEN');
      expect(
        ((await relative.loadMobile('relative'))['notifications'] as List)
            .where((n) => n['type'] == 'pickup'),
        isEmpty,
      );
      final pickup = await store.changeSessionStatus(
        session.id,
        SessionStatus.readyForPickUp,
      );
      expect(pickup.changed, true);
      expect(pickup.notificationCount, 2);
      final repeated = await store.changeSessionStatus(
        session.id,
        SessionStatus.readyForPickUp,
      );
      expect(repeated.changed, false);
      expect(repeated.notificationCount, 0);
      await store.addSchedule(
        store.patientFor(pid),
        DateTime.now().add(const Duration(days: 1)),
        'Batch A',
      );
      final update = await relative.loadMobile('relative');
      final sessions = (update['sessions'] as List)
          .map(
            (s) => SessionRecord.fromJson(Map<String, dynamic>.from(s as Map)),
          )
          .toList();
      expect(
        currentDialysisSession(sessions, DateTime.now())?.status,
        SessionStatus.readyForPickUp,
      );
      expect(nextDialysisSession(sessions, DateTime.now()), isNotNull);
      final notification = (update['notifications'] as List)
          .cast<Map>()
          .firstWhere((n) => n['type'] == 'pickup');
      expect(notification['readAt'], isNull);
      await relative.call('readNotification', {'id': notification['id']});
      final afterRead = await relative.loadMobile('relative');
      expect(
        (afterRead['notifications'] as List).cast<Map>().firstWhere(
          (n) => n['id'] == notification['id'],
        )['readAt'],
        isNotNull,
      );
      stdout.writeln('LIVE_STAFFSTORE_STATUS_AND_AUTOMATIC_PICKUP_VERIFIED');
      final future = DateTime.now().add(const Duration(days: 2));
      await store.addSchedule(
        store.patientFor(pid),
        future,
        'Verification Batch',
      );
      final interrupted = store.sessions.firstWhere(
        (s) => s.patientId == pid && s.start.isAtSameMomentAs(future),
      );
      await store.changeSessionStatus(interrupted.id, SessionStatus.inProgress);
      await store.changeSessionStatus(
        interrupted.id,
        SessionStatus.paused,
        reasonCode: 'equipment',
        note: 'PRIVATE EARLY END TEST',
      );
      await store.changeSessionStatus(
        interrupted.id,
        SessionStatus.endedEarly,
        reasonCode: 'clinicalDecision',
        note: 'PRIVATE END NOTE',
      );
      final ended = store.sessions.firstWhere((s) => s.id == interrupted.id);
      expect(ended.endedAt, isNotNull);
      expect(ended.completedAt, isNull);
      for (final mobile in [(patient, 'patient'), (relative, 'relative')]) {
        final data = await mobile.$1.loadMobile(mobile.$2);
        final restored = SessionRecord.fromJson(
          Map<String, dynamic>.from(
            (data['sessions'] as List).firstWhere((s) => s['id'] == ended.id)
                as Map,
          ),
        );
        expect(restored.status, SessionStatus.endedEarly);
        expect(
          restored.elapsedAt(DateTime.now().add(const Duration(days: 10))),
          ended.elapsedAt(DateTime.now()),
        );
        expect(jsonEncode(data).contains('PRIVATE END NOTE'), false);
      }
      await expectLater(
        store.changeSessionStatus(ended.id, SessionStatus.inProgress),
        throwsStateError,
      );
      final events = await staff.sessionHistory(ended.id);
      expect(
        events.map((e) => e['type']).toSet(),
        containsAll(['START', 'PAUSE', 'END_EARLY']),
      );
      stdout.writeln(
        'LIVE_END_EARLY_FROZEN_PRIVATE_HISTORY_PATIENT_RELATIVE_VERIFIED',
      );
    },
    skip: raw == null
        ? 'Requires the explicit disposable live verification runner.'
        : false,
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

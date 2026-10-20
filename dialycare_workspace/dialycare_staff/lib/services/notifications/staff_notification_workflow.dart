part of '../staff_store.dart';

String _notificationId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${List.generate(8, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
Patient _migrateRelativeIds(Patient p) => Patient.fromJson({
  ...p.toJson(),
  'companions': [
    for (var i = 0; i < p.companions.length; i++)
      {
        ...p.companions[i].toJson(),
        'id': p.companions[i].id.isEmpty
            ? '${p.id}-legacy-relative-${i + 1}'
            : p.companions[i].id,
      },
  ],
});
String notificationTitle(NotificationType type) => switch (type) {
  NotificationType.scheduleReminder => 'Schedule Reminder',
  NotificationType.sessionStarted => 'Session Started',
  NotificationType.sessionPaused => 'Session Paused',
  NotificationType.sessionResumed => 'Session Resumed',
  NotificationType.sessionEndedEarly => 'Session Ended Early',
  NotificationType.sessionCompleted => 'Session Completed',
  NotificationType.scheduleCreated => 'Schedule Created',
  NotificationType.endingSoon => 'Session Ending Soon',
  NotificationType.pickup => 'Pickup Notification',
  NotificationType.scheduleUpdated => 'Schedule Updated',
  NotificationType.scheduleRescheduled => 'Schedule Rescheduled',
  NotificationType.scheduleCancelled => 'Schedule Cancelled',
};
String notificationMessage(
  NotificationType type,
  Patient p,
  SessionRecord s,
  RecipientType recipient,
) => switch (type) {
  NotificationType.sessionPaused => 'The dialysis session is temporarily paused. The center will update the session status.',
  NotificationType.sessionResumed => 'Dialysis session resumed.',
  NotificationType.sessionEndedEarly => 'The dialysis session ended early. Please contact the dialysis center for additional information.',
  NotificationType.sessionCompleted =>
    '${p.name}\'s session was marked completed by the center. Please wait for a separate Ready for Pick Up update.',
  NotificationType.pickup =>
    recipient == RecipientType.patient
        ? 'Your dialysis session is complete. You are ready for pickup.\n${s.room}'
        : '${p.name} is ready for pickup.\nDialysis Center • ${s.room}',
  NotificationType.sessionStarted =>
    '${p.name}\'s dialysis session has started. See session progress for the recorded actual start.\nRoom: ${s.room}',
  NotificationType.endingSoon =>
    '${p.name}\'s dialysis session is expected to end at ${(s.estimatedEnd ?? s.expectedEnd) == null ? 'the recorded end time' : sessionTime((s.estimatedEnd ?? s.expectedEnd)!)}.\n${s.room}',
  NotificationType.scheduleCancelled =>
    '${p.name}\'s dialysis session on ${shortDate(s.start)} at ${sessionTime(s.start)} has been cancelled.',
  _ =>
    '${p.name}\'s dialysis session is scheduled for ${shortDate(s.start)} at ${sessionTime(s.start)}.\n${s.room} • ${s.batch}',
};

extension StaffNotificationWorkflow on StaffStore {
  bool _replacesRelative(Patient? old, Companion input) {
    final previous = old?.companions.where((c) => c.id == input.id).firstOrNull;
    return previous != null &&
        (previous.name.trim().toLowerCase() !=
                input.name.trim().toLowerCase() ||
            previous.contact.replaceAll(RegExp(r'\D'), '') !=
                input.contact.replaceAll(RegExp(r'\D'), ''));
  }

  Patient _preparePatient(Patient input) {
    final old = patients.where((p) => p.id == input.id).firstOrNull;
    final registration = old == null
        ? input.registration
        : old.contact == input.contact
        ? old.registration
        : old.registration.status == AppRegistrationStatus.notRegistered
        ? const AppRegistration()
        : old.registration.invalidated();
    String relativePublicId(Companion input) {
      if (input.id.isNotEmpty && !_replacesRelative(old, input)) {
        final previous = old?.companions
            .where((c) => c.id == input.id)
            .firstOrNull;
        if (previous != null && previous.publicId.isNotEmpty) {
          return previous.publicId;
        }
        if (input.publicId.isNotEmpty) return input.publicId;
      }
      return sequentialCenterId('R-', _nextRelativeNumber++);
    }

    final companions = [
      for (final c in input.companions)
        Companion.fromJson({
          ...c.toJson(),
          'publicId': relativePublicId(c),
          'id': c.id.isEmpty || _replacesRelative(old, c)
              ? 'R-${_notificationId()}'
              : c.id,
          'mobileAccount': _replacesRelative(old, c)
              ? const MobileAccount().toJson()
              : (old?.companions
                            .where((r) => r.id == c.id)
                            .firstOrNull
                            ?.mobileAccount ??
                        c.mobileAccount)
                    .toJson(),
          'registration': (() {
            if (_replacesRelative(old, c)) return const AppRegistration();
            final existing = old?.companions
                .where((r) => r.id == c.id)
                .firstOrNull;
            return existing == null
                ? c.registration
                : existing.contact == c.contact
                ? existing.registration
                : existing.registration.status ==
                      AppRegistrationStatus.notRegistered
                ? const AppRegistration()
                : existing.registration.invalidated();
          })().toJson(),
        }),
    ];
    final legacyId = old == null
        ? 'Not assigned'
        : centerIdLabel(old.id, 'DC-');
    return Patient.fromJson({
      ...input.toJson(),
      'publicId': old != null
          ? (old.publicId.isNotEmpty
                ? old.publicId
                : legacyId == 'Not assigned'
                ? nextPatientId
                : legacyId)
          : (input.publicId.isNotEmpty ? input.publicId : nextPatientId),
      'recordStatus': old?.recordStatus ?? input.recordStatus,
      'archivedAt': old?.archivedAt?.toUtc().toIso8601String(),
      'archivedBy': old?.archivedBy,
      'mobileAccount': (old?.mobileAccount ?? input.mobileAccount).toJson(),
      'registration': registration.toJson(),
      'companions': companions.map((c) => c.toJson()).toList(),
    });
  }

  List<NotificationRecipient> recipientsFor(String patientId) =>
      const RecipientResolver().resolve(
        _migrateRelativeIds(patientFor(patientId)),
      );
  Future<void> syncRegistrations(RegistrationSource source) async {
    final registrations = await source.fetchRegistrations();
    await _commit(() {
      for (final item in registrations) {
        if (!item.registration.backendVerified) {
          throw StateError('Registration source did not verify its record.');
        }
        final i = patients.indexWhere((p) => p.id == item.patientId);
        if (i < 0) continue;
        final p = _migrateRelativeIds(patients[i]);
        if (item.type == RecipientType.patient && item.recipientId == p.id) {
          patients[i] = Patient.fromJson({
            ...p.toJson(),
            'registration': item.registration.toJson(),
          });
        } else if (item.type == RecipientType.relative) {
          patients[i] = Patient.fromJson({
            ...p.toJson(),
            'companions': [
              for (final c in p.companions)
                {
                  ...c.toJson(),
                  'registration': c.id == item.recipientId
                      ? item.registration.toJson()
                      : c.registration.toJson(),
                },
            ],
          });
        }
      }
    });
  }

  List<NotificationDelivery> _enqueue(
    SessionRecord s,
    NotificationType type,
    String eventId, {
    NotificationTrigger trigger = NotificationTrigger.automatic,
    Set<String>? recipientIds,
    String? message,
  }) {
    if (notificationEvents.any((e) => e.id == eventId)) return [];
    final patient = patientFor(s.patientId);
    if (patient.archived) {
      return [];
    }
    final recipients = const RecipientResolver()
        .resolve(
          _migrateRelativeIds(patient),
          includePatient: recipientIds != null || deliveryRules.notifyPatient,
          includeRelatives:
              recipientIds != null || deliveryRules.notifyRelatives,
        )
        .where((r) => recipientIds == null || recipientIds.contains(r.id))
        .toList();
    final now = DateTime.now();
    notificationEvents.add(
      NotificationEvent(
        id: eventId,
        sessionId: s.id,
        type: type,
        trigger: trigger,
        createdAt: now,
      ),
    );
    final records = [
      for (final r in recipients)
        NotificationDelivery(
          id: 'D-${_notificationId()}',
          eventId: eventId,
          patientId: s.patientId,
          recipientId: r.id,
          recipientType: r.type,
          recipientName: r.name,
          type: type,
          title: notificationTitle(type),
          message: message ?? notificationMessage(type, patient, s, r.type),
          trigger: trigger,
          sessionId: s.id,
          createdAt: now,
          attempts: shared
              ? [
                  DeliveryAttempt(
                    channel: DeliveryChannel.inApp,
                    status: DeliveryStatus.available,
                    createdAt: now,
                    reason: 'Persisted in Firestore for the authorized recipient. Push/SMS not attempted.',
                  ),
                ]
              : const [],
        ),
    ];
    deliveryHistory.insertAll(0, records);
    return records;
  }

  Future<void> _dispatch(List<NotificationDelivery> records) async {
    // The atomic shared save already persisted these in-app notifications.
    // No push/SMS provider is called or falsely reported as delivered on Spark.
    if (shared) return;
    for (final record in records) {
      if (!_activeDeliveries.add(record.id)) continue;
      try {
        final recipient = recipientsFor(record.patientId)
            .where((r) => r.id == record.recipientId)
            .firstOrNull;
        if (recipient == null) {
          await _commit(() {
            final i = deliveryHistory.indexWhere((d) => d.id == record.id);
            deliveryHistory[i] = record.copyWith(
              attempts: [
                DeliveryAttempt(
                  channel: DeliveryChannel.sms,
                  status: DeliveryStatus.failed,
                  createdAt: DateTime.now(),
                  reason: 'Recipient is no longer available or has disabled notifications.',
                ),
              ],
            );
          });
          continue;
        }
        await deliveryService.deliver(
          delivery: record,
          recipient: recipient,
          save: (attempt, {replacePending = false}) => _commit(() {
            final i = deliveryHistory.indexWhere((d) => d.id == record.id);
            final current = deliveryHistory[i];
            final attempts = List<DeliveryAttempt>.of(current.attempts);
            if (replacePending &&
                attempts.isNotEmpty &&
                attempts.last.status == DeliveryStatus.pending) {
              attempts[attempts.length - 1] = attempt;
            } else {
              attempts.add(attempt);
            }
            deliveryHistory[i] = current.copyWith(attempts: attempts);
          }),
          invalidate: () => _commit(() {
            final i = patients.indexWhere((p) => p.id == record.patientId);
            if (i < 0) return;
            final p = patients[i];
            // Do not invalidate a newer registration that arrived during delivery.
            if (record.recipientType == RecipientType.patient &&
                p.registration.pushToken == recipient.registration.pushToken) {
              patients[i] = Patient.fromJson({
                ...p.toJson(),
                'registration': p.registration.invalidated().toJson(),
              });
            }
            if (record.recipientType == RecipientType.relative) {
              patients[i] = Patient.fromJson({
                ...p.toJson(),
                'companions': [
                  for (final c in p.companions)
                    {
                      ...c.toJson(),
                      'registration':
                          c.id == record.recipientId &&
                              c.registration.pushToken ==
                                  recipient.registration.pushToken
                          ? c.registration.invalidated().toJson()
                          : c.registration.toJson(),
                    },
                ],
              });
            }
          }),
        );
      } finally {
        _activeDeliveries.remove(record.id);
      }
    }
  }

  Future<List<NotificationDelivery>> sendReminder(
    String sessionId, {
    required Set<String> recipientIds,
    String? message,
  }) async {
    if (recipientIds.isEmpty) {
      throw StateError('Select at least one recipient.');
    }
    if (message != null && message.trim().isEmpty) {
      throw StateError('Enter a reminder message.');
    }
    var records = <NotificationDelivery>[];
    await _commit(() {
      final session = sessions.firstWhere((s) => s.id == sessionId);
      if (patientFor(session.patientId).archived) {
        throw StateError('Restore the Patient before sending a new reminder.');
      }
      if (session.status == SessionStatus.cancelled) {
        throw StateError('This schedule is cancelled.');
      }
      final available = recipientsFor(session.patientId)
          .map((r) => r.id)
          .toSet();
      if (!recipientIds.every(available.contains)) {
        throw StateError('A selected recipient is no longer available.');
      }
      records = _enqueue(
        session,
        NotificationType.scheduleReminder,
        'manual-${_notificationId()}',
        trigger: NotificationTrigger.staff,
        recipientIds: recipientIds,
        message: message?.trim(),
      );
      if (records.isEmpty) {
        throw StateError('Notifications are disabled for these recipients.');
      }
    });
    await _dispatch(records);
    return [
      for (final r in records) deliveryHistory.firstWhere((d) => d.id == r.id),
    ];
  }

  Future<SessionStatusUpdateResult> changeSessionStatus(
    String id,
    SessionStatus status, {
    int? expectedRevision,
    DateTime? expectedEnd,
    String? reasonCode,
    String note = '',
  }) async {
    var changed = false;
    var records = <NotificationDelivery>[];
    await _commit(() {
      if (!signedIn) throw StateError('Sign in to manage dialysis sessions.');
      final i = sessions.indexWhere((s) => s.id == id);
      if (i < 0) throw StateError('Session no longer exists.');
      final previous = sessions[i];
      if (!sessionTransitionAllowed(previous.status, status)) {
        throw StateError(
          'Invalid transition: ${previous.status.label} to ${status.label}.',
        );
      }
      final needsReason =
          [
            SessionStatus.paused,
            SessionStatus.endedEarly,
            SessionStatus.cancelled,
          ].contains(status) &&
          status != previous.status;
      if (needsReason &&
          !(status == SessionStatus.paused ? pauseReasonCodes : endReasonCodes)
              .contains(reasonCode)) {
        throw StateError('Select an operational reason before continuing.');
      }
      if (note.length > 500) {
        throw StateError('Internal note must be at most 500 characters.');
      }
      if (status == SessionStatus.inProgress &&
          previous.actualStartedAt == null &&
          !validPlannedDuration(previous.plannedDurationMinutes)) {
        throw StateError(
          'Set the planned duration in Edit Schedule before starting this session.',
        );
      }
      if (expectedRevision != null && previous.revision != expectedRevision) {
        throw StateError(
          'This session has changed. Close this panel and reopen the current record.',
        );
      }
      if (previous.status == status &&
          (expectedEnd == null || expectedEnd == previous.expectedEnd)) {
        return;
      }
      if (expectedEnd != null && !expectedEnd.isAfter(previous.start)) {
        throw StateError('Expected end must be after the session start.');
      }
      final now = DateTime.now().toUtc();
      final intervals = {...previous.pauseIntervals};
      var sequence = previous.pauseSequence;
      if (status == SessionStatus.paused && previous.status != status) {
        sequence++;
        intervals['p$sequence'] = PauseInterval(pausedAt: now);
      }
      if (previous.status == SessionStatus.paused &&
          previous.status != status) {
        final old = intervals['p$sequence']!;
        intervals['p$sequence'] = PauseInterval(
          pausedAt: old.pausedAt,
          resumedAt: now,
        );
      }
      final s = SessionRecord.fromJson({
        ...previous.toJson(),
        'status': status.label,
        if (sequence > 0) 'pauseSequence': sequence,
        if (intervals.isNotEmpty)
          'pauseIntervals': intervals.map((k, v) => MapEntry(k, v.toJson())),
        if ([
          SessionStatus.endedEarly,
          SessionStatus.cancelled,
        ].contains(status))
          'endedAt': now.toIso8601String(),
        if (status == SessionStatus.inProgress &&
            previous.actualStartedAt == null)
          'actualStartedAt': DateTime.now().toUtc().toIso8601String(),
        if (status == SessionStatus.completed && previous.completedAt == null)
          'completedAt': DateTime.now().toUtc().toIso8601String(),
        'revision': previous.revision + 1,
        'expectedEnd': (expectedEnd ?? previous.expectedEnd)?.toIso8601String(),
        'progress':
            status == SessionStatus.completed ||
                status == SessionStatus.readyForPickUp
            ? 1.0
            : status == SessionStatus.inProgress && previous.ongoing
            ? previous.progress
            : 0.0,
      });
      sessions[i] = s;
      if (previous.status != status) {
        sessionEvents.add({
          'id': '${s.id}_${s.revision}',
          'sessionId': s.id,
          'patientId': s.patientId,
          'revision': s.revision,
          'fromStatus': previous.status.label,
          'toStatus': status.label,
          'type': status == SessionStatus.inProgress
              ? (previous.status == SessionStatus.paused ? 'RESUME' : 'START')
              : status == SessionStatus.paused
              ? 'PAUSE'
              : status == SessionStatus.completed
              ? 'COMPLETE'
              : status == SessionStatus.endedEarly
              ? 'END_EARLY'
              : status == SessionStatus.cancelled
              ? 'CANCEL'
              : 'STATUS',
          'actorUid': actorUid,
          'reasonCode': needsReason ? reasonCode : '',
          'note': needsReason ? note.trim() : '',
          'timestamp': now.toIso8601String(),
        });
      }
      changed = true;
      NotificationType? type;
      if (status != previous.status) {
        type = status == SessionStatus.inProgress
            ? (previous.status == SessionStatus.paused
                  ? NotificationType.sessionResumed
                  : NotificationType.sessionStarted)
            : status == SessionStatus.paused
            ? NotificationType.sessionPaused
            : status == SessionStatus.endedEarly
            ? NotificationType.sessionEndedEarly
            : status == SessionStatus.completed
            ? NotificationType.sessionCompleted
            : status == SessionStatus.readyForPickUp
            ? NotificationType.pickup
            : status == SessionStatus.cancelled
            ? NotificationType.scheduleCancelled
            : null;
      }
      if (type != null) {
        records = _enqueue(s, type, '${s.id}:${type.name}:${s.revision}');
      }
    });
    String? deliveryWarning;
    try {
      await _dispatch(records);
    } catch (_) {
      deliveryWarning = 'Session saved, but some notification results could not be recorded. Check history before retrying.';
    }
    return SessionStatusUpdateResult(
      changed: changed,
      notificationCount: records.length,
      deliveryWarning: deliveryWarning,
    );
  }

  Future<void> updateSchedule(
    String id, {
    required DateTime start,
    required String room,
    required String batch,
    int? plannedDurationMinutes,
  }) async {
    if (plannedDurationMinutes != null &&
        !validPlannedDuration(plannedDurationMinutes)) {
      throw StateError('Planned duration must be 30–720 minutes.');
    }
    var records = <NotificationDelivery>[];
    await _commit(() {
      final i = sessions.indexWhere((s) => s.id == id);
      if (i < 0) throw StateError('Schedule no longer exists.');
      final old = sessions[i];
      if (old.status == SessionStatus.cancelled) {
        throw StateError('Cancelled schedules cannot be edited.');
      }
      if (start == old.start &&
          room == old.room &&
          batch == old.batch &&
          (plannedDurationMinutes == null ||
              plannedDurationMinutes == old.plannedDurationMinutes)) {
        return;
      }
      if (old.actualStartedAt != null || old.finished) {
        throw StateError('Only unstarted schedules can be edited.');
      }
      if (start != old.start ||
          batch != old.batch ||
          (plannedDurationMinutes != null &&
              plannedDurationMinutes != old.plannedDurationMinutes)) {
        checkSlot(
          old.patientId,
          start,
          batch,
          plannedDurationMinutes ?? old.plannedDurationMinutes ?? 720,
          excluding: id,
        );
      }
      final s = SessionRecord.fromJson({
        ...old.toJson(),
        'start': start.toIso8601String(),
        'room': room,
        'batch': batch,
        'plannedDurationMinutes': ?plannedDurationMinutes,
        'expectedEnd': old.expectedEnd
            ?.add(start.difference(old.start))
            .toIso8601String(),
        'revision': old.revision + 1,
      });
      sessions[i] = s;
      sessions.sort((a, b) => a.start.compareTo(b.start));
      final type = start != old.start
          ? NotificationType.scheduleRescheduled
          : NotificationType.scheduleUpdated;
      records = _enqueue(s, type, '${s.id}:${type.name}:${s.revision}');
    });
    await _dispatch(records);
  }

  // Backend/job-scheduler entry point, deliberately not called from build() or a UI timer.
  // Persisted event keys survive restarts and deduplicate scheduled notifications.
  Future<void> processDueNotifications(DateTime now) async {
    var records = <NotificationDelivery>[];
    await _commit(() {
      for (final s in sessions) {
        if (patientFor(s.patientId).archived) {
          continue;
        }
        if (s.upcoming &&
            !now.isBefore(s.start.subtract(deliveryRules.reminderLead)) &&
            now.isBefore(s.start)) {
          records.addAll(
            _enqueue(
              s,
              NotificationType.scheduleReminder,
              '${s.id}:reminder:${s.start.toIso8601String()}',
            ),
          );
        }
        final estimated =
            s.estimatedEndAt(now) ??
            (s.pauseIntervals.isEmpty ? s.expectedEnd : null);
        if (s.status == SessionStatus.inProgress &&
            estimated != null &&
            !now.isBefore(estimated.subtract(deliveryRules.endingSoonLead)) &&
            now.isBefore(estimated)) {
          records.addAll(
            _enqueue(s, NotificationType.endingSoon, '${s.id}:ending'),
          );
        }
      }
    });
    await _dispatch(records);
  }
}

import 'dart:convert';
import 'dart:math';

import 'package:core_shared/core_shared.dart'
    show
        MobileAccount,
        BackendException,
        sequentialCenterId,
        centerIdLabel,
        validPlannedDuration,
        sessionTransitionAllowed,
        PauseInterval,
        pauseReasonCodes,
        endReasonCodes;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../models/patient.dart';
import '../models/notification_delivery.dart';
import 'notifications/providers.dart';
import 'notifications/notification_service.dart';

import '../models/session.dart';
import '../models/session_batch.dart';
import '../theme/staff_theme.dart';
import 'mock_data.dart' as seed;
import 'storage/local_storage.dart';

part 'notifications/staff_notification_workflow.dart';

String _passwordKey(List<String> data) {
  final mac = Hmac(sha256, utf8.encode(data[0]));
  var u = mac.convert([...base64Decode(data[1]), 0, 0, 0, 1]).bytes;
  final key = List<int>.from(u);
  for (var i = 1; i < 100000; i++) {
    u = mac.convert(u).bytes;
    for (var n = 0; n < key.length; n++) {
      key[n] ^= u[n];
    }
  }
  return base64Encode(key);
}

class StaffStore extends ChangeNotifier {
  StaffStore({
    this.memoryOnly = false,
    this.shared = false,
    DateTime? now,
    this.readData,
    this.issueActivation,
    this.cancelMobileAccess,
    this.changeMobileAccess,
    this.writeData,
    this.saveCenterInformation,
    this.readAuditEvents,
    this.readSessionEvents,
    this.deliveryService = const NotificationService(),
    this.deliveryRules = const DeliveryRules(),
  }) {
    final today = now ?? DateTime.now();
    patients = List.of(seed.patients);
    sessions = [
      for (var i = 0; i < patients.length; i++)
        SessionRecord(
          id: 'S-${i + 1}',
          patientId: patients[i].id,
          start: DateTime(
            today.year,
            today.month,
            today.day,
            8 + i ~/ 2,
            (i % 2) * 15,
          ),
          room: patients[i].room,
          batch: patients[i].batch,
          status: SessionStatus.fromStorage(patients[i].status),
          progress: patients[i].status == 'In Progress'
              ? (i == 0 ? .3 : .75)
              : patients[i].status == 'Completed'
              ? 1
              : 0,
        ),
      SessionRecord(
        id: 'S-7',
        patientId: patients[0].id,
        start: DateTime(today.year, today.month, today.day, 14),
        room: 'Room 01',
        batch: 'Batch A',
        status: SessionStatus.pending,
      ),
      SessionRecord(
        id: 'S-8',
        patientId: patients[1].id,
        start: DateTime(today.year, today.month, today.day, 14, 30),
        room: 'Room 02',
        batch: 'Batch B',
        status: SessionStatus.pending,
      ),
      SessionRecord(
        id: 'S-9',
        patientId: patients[4].id,
        start: DateTime(today.year, today.month, today.day - 1, 9),
        room: 'Room 05',
        batch: 'Batch C',
        status: SessionStatus.missed,
      ),
    ];
    notifications = [
      for (var i = 0; i < seed.notificationItems.length; i++)
        StaffNotification(
          id: 'N-$i',
          category: seed.notificationItems[i]['type']!,
          title: seed.notificationItems[i]['title']!,
          message: seed.notificationItems[i]['message']!,
          icon: seed.notificationItems[i]['icon']!,
          time: DateTime(today.year, today.month, today.day, 8),
        ),
    ];
  }
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  final NotificationService deliveryService;
  final DeliveryRules deliveryRules;
  List<NotificationDelivery> deliveryHistory = [];
  List<NotificationEvent> notificationEvents = [];
  final Set<String> _activeDeliveries = {};
  final bool memoryOnly, shared;
  final Future<Map<String, dynamic>> Function(
    String role,
    String patientId,
    String recipientId,
  )?
  issueActivation;
  final Future<void> Function(String role, String recipientId)?
  cancelMobileAccess;
  final Future<void> Function(String role, String recipientId, bool enabled)?
  changeMobileAccess;
  final Future<String?> Function()? readData;
  final Future<void> Function(String)? writeData;
  final Future<void> Function(Map<String, dynamic>)? saveCenterInformation;
  final Future<List<Map<String, dynamic>>> Function()? readAuditEvents;
  Future<void> refreshAuditActivity() async {
    final events = await readAuditEvents?.call();
    if (events != null) {
      auditEvents = events;
      _notify();
    }
  }

  final Future<List<Map<String, dynamic>>> Function(String)? readSessionEvents;
  List<Map<String, dynamic>> sessionEvents = [];
  Future<List<Map<String, dynamic>>> sessionHistory(String id) async {
    final rows = await readSessionEvents?.call(id);
    if (rows != null) {
      sessionEvents.removeWhere((e) => e['sessionId'] == id);
      sessionEvents.addAll(rows);
    }
    return sessionEvents.where((e) => e['sessionId'] == id).toList()
      ..sort((a, b) => (a['revision'] as int).compareTo(b['revision'] as int));
  }

  String actorRole = 'staff', actorUid = '';
  String? workspaceVersion;
  bool get isCenterAdmin => actorRole == 'admin';
  String get roleLabel => isCenterAdmin ? 'Center Admin' : 'Staff';
  Map<String, dynamic> centerInformation = {
    'name': 'DialyCare',
    'contact': '',
    'address': '',
  };
  List<Map<String, dynamic>> auditEvents = [];
  Map<String, String> publicIdLabels = {};
  String publicIdFor(String internalId) {
    final label = publicIdLabels[internalId];
    if (label != null && label != 'Not assigned') return label;
    for (final patient in patients) {
      if (patient.id == internalId) return patient.displayId;
      for (final relative in patient.companions) {
        if (relative.id == internalId) return relative.displayId;
      }
    }
    final formatted = centerIdLabel(
      internalId,
      internalId.startsWith('DC-') ? 'DC-' : 'R-',
    );
    return formatted == 'Not assigned' ? 'Historical record' : formatted;
  }

  String auditResourceLabel(Map<String, dynamic> event) {
    final id = event['resourceId'] as String? ?? '';
    if (event['resourceType'] == 'session') {
      final session = sessions.where((s) => s.id == id).firstOrNull;
      return session == null
          ? 'Session record'
          : '${publicIdFor(session.patientId)} • ${shortDate(session.start)}';
    }
    if (event['resourceType'] == 'notification') {
      final notification = deliveryHistory.where((n) => n.id == id).firstOrNull;
      return notification == null
          ? 'Notification record'
          : publicIdFor(notification.patientId);
    }
    return event['resourceType'] == 'settings'
        ? 'Center information'
        : publicIdFor(id);
  }

  Iterable<Patient> get activePatients => patients.where((p) => !p.archived);
  final _storage = LocalStorage();
  late List<Patient> patients;
  late List<SessionRecord> sessions;
  late List<StaffNotification> notifications;
  String staffName = 'Yrxyxy', passwordSalt = '', passwordHash = '';
  bool signedIn = true;
  String? loadError;
  Future<void> _writes = Future.value();
  int _nextPatientNumber = 1;
  int _nextRelativeNumber = 1;
  List<Map<String, dynamic>> batchConfigurations = [];
  Map<String, dynamic>? batchConfiguration(String name) => batchConfigurations
      .where((b) => b['name'] == name && b['active'] == true)
      .firstOrNull;
  Future<void> configureBatch(Map<String, dynamic> config) => _commit(() {
    if (!isCenterAdmin) throw StateError('Center Admin access required.');
    final i = batchConfigurations.indexWhere((b) => b['id'] == config['id']);
    if (i < 0) {
      batchConfigurations.add(config);
    } else {
      batchConfigurations[i] = config;
    }
  });
  void checkSlot(
    String patientId,
    DateTime start,
    String batch,
    int minutes, {
    String? excluding,
  }) {
    final config = batchConfiguration(batch),
        capacity = config?['capacity'] as int?;
    if (capacity != null &&
        sessions
                .where(
                  (s) =>
                      s.id != excluding &&
                      s.batch == batch &&
                      sameDay(s.start, start) &&
                      s.status != SessionStatus.cancelled &&
                      s.status != SessionStatus.missed,
                )
                .map((s) => s.patientId)
                .toSet()
                .length >=
            capacity) {
      throw StateError('This batch has reached its configured capacity.');
    }
    if (sessions.any(
      (s) =>
          s.id != excluding &&
          s.patientId == patientId &&
          s.status != SessionStatus.cancelled &&
          s.status != SessionStatus.missed &&
          start.isBefore(
            s.start.add(Duration(minutes: s.plannedDurationMinutes ?? 720)),
          ) &&
          start.add(Duration(minutes: minutes)).isAfter(s.start),
    )) {
      throw StateError('This Patient already has an overlapping appointment.');
    }
  }

  List<String> get batches => [
    'All Batches',
    ...({
      if (batchConfigurations.isNotEmpty)
        ...batchConfigurations
            .where((b) => b['active'] == true)
            .map((b) => b['name'] as String)
      else
        ...activePatients.map((p) => p.batch),
      ...sessions.map((s) => s.batch),
    }.where((b) => b.trim().isNotEmpty).toList()..sort(compareBatchNames)),
  ];
  Patient patientFor(String id) => patients.firstWhere((p) => p.id == id);
  String get nextPatientId {
    var next = _nextPatientNumber;
    for (final p in patients) {
      final n = int.tryParse(p.displayId.replaceFirst('DC-', ''));
      if (n != null && n >= next) {
        next = n + 1;
      }
    }
    return sequentialCenterId('DC-', next);
  }

  Map<String, dynamic> _snapshot() => {
    'version': 2,
    'batchConfigurations': batchConfigurations
        .map((b) => Map<String, dynamic>.from(b))
        .toList(),
    'workspaceVersion': workspaceVersion,
    'actorRole': actorRole,
    'actorUid': actorUid,
    'centerInformation': centerInformation,
    'auditEvents': auditEvents,
    'sessionEvents': sessionEvents
        .map((e) => Map<String, dynamic>.from(e))
        .toList(),
    'publicIdLabels': publicIdLabels,
    'nextPatientNumber': _nextPatientNumber,
    'nextRelativeNumber': _nextRelativeNumber,
    'deliveryHistory': deliveryHistory.map((d) => d.toJson()).toList(),
    'notificationEvents': notificationEvents.map((e) => e.toJson()).toList(),
    'patients': patients.map((p) => p.toJson()).toList(),
    'sessions': sessions.map((s) => s.toJson()).toList(),
    'notifications': notifications.map((n) => n.toJson()).toList(),
    'staffName': staffName,
    'passwordSalt': passwordSalt,
    'passwordHash': passwordHash,
  };
  void _restore(Map<String, dynamic> j) {
    // Decode everything before replacing live state; never partially load a damaged file.
    final p = (j['patients'] as List)
        .map((v) => Patient.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList();
    final ids = p.map((p) => p.id).toSet();
    final s = (j['sessions'] as List)
        .map((v) => SessionRecord.fromJson(Map<String, dynamic>.from(v as Map)))
        .where((s) => ids.contains(s.patientId))
        .toList();
    final n = (j['notifications'] as List)
        .map(
          (v) =>
              StaffNotification.fromJson(Map<String, dynamic>.from(v as Map)),
        )
        .toList();
    final history = ((j['deliveryHistory'] as List?) ?? [])
        .map(
          (d) => NotificationDelivery.fromJson(
            Map<String, dynamic>.from(d as Map),
          ),
        )
        .toList();
    final events = ((j['notificationEvents'] as List?) ?? [])
        .map(
          (e) =>
              NotificationEvent.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    batchConfigurations = [
      for (final b in j['batchConfigurations'] as List? ?? [])
        Map<String, dynamic>.from(b as Map),
    ];
    patients = p.map(_migrateRelativeIds).toList();
    workspaceVersion = j['workspaceVersion'] as String?;
    publicIdLabels = (j['publicIdLabels'] as Map? ?? {}).map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    );
    actorRole = j['actorRole'] as String? ?? actorRole;
    actorUid = j['actorUid'] as String? ?? actorUid;
    centerInformation = Map<String, dynamic>.from(
      j['centerInformation'] as Map? ?? centerInformation,
    );
    if (j.containsKey('auditEvents')) {
      auditEvents = [
        for (final e in j['auditEvents'] as List? ?? [])
          Map<String, dynamic>.from(e as Map),
      ];
    }
    sessionEvents = [
      for (final e in j['sessionEvents'] as List? ?? [])
        Map<String, dynamic>.from(e as Map),
    ];
    deliveryHistory = history;
    notificationEvents = events;
    sessions = s;
    notifications = n;
    staffName = j['staffName'] as String? ?? 'Yrxyxy';
    _nextPatientNumber = j['nextPatientNumber'] as int? ?? 1;
    _nextRelativeNumber = j['nextRelativeNumber'] as int? ?? 1;
    for (final patient in patients) {
      final number = int.tryParse(patient.displayId.replaceFirst('DC-', ''));
      if (number != null && number >= _nextPatientNumber) {
        _nextPatientNumber = number + 1;
      }
    }
    passwordSalt = j['passwordSalt'] as String? ?? '';
    passwordHash = j['passwordHash'] as String? ?? '';
  }

  /// Serialize refreshes with saves so polling cannot replace an in-flight edit.
  Future<void> refreshShared() {
    final operation = _writes.then((_) => load());
    _writes = operation.then((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<void> load() async {
    if (memoryOnly) {
      return;
    }
    try {
      final data = await (readData?.call() ?? _storage.read());
      loadError = null;
      if (data != null) {
        _restore(Map<String, dynamic>.from(jsonDecode(data) as Map));
        signedIn = passwordHash.isEmpty;
      }
    } catch (failure) {
      loadError = failure is BackendException ? failure.message : 'Saved workspace could not be read. Your saved file has not been changed.';
    }
    _notify();
  }

  Future<void> _commit(VoidCallback change) {
    final operation = _writes.then((_) async {
      if (loadError != null) {
        throw StateError(
          'Resolve the saved workspace error before saving changes.',
        );
      }
      final before = _snapshot();
      try {
        change();
        if (!memoryOnly) {
          await (writeData?.call(jsonEncode(_snapshot())) ??
              _storage.write(jsonEncode(_snapshot())));
        }
      } catch (_) {
        _restore(before);
        _notify();
        rethrow;
      }
      _notify();
    });
    _writes = operation.then((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<void> savePatient(Patient patient, {String? expectedVersion}) =>
      _commit(() {
        if (expectedVersion != null && expectedVersion != workspaceVersion) {
          throw const BackendException(
            'The workspace changed while you were editing. Reopen the Patient record before saving.',
            409,
          );
        }
        patient = _preparePatient(patient);
        final i = patients.indexWhere((p) => p.id == patient.id);
        if (i < 0) {
          final number = int.tryParse(
            patient.displayId.replaceFirst('DC-', ''),
          );
          if (number != null && number >= _nextPatientNumber) {
            _nextPatientNumber = number + 1;
          }
          patients.add(patient);
        } else {
          patients[i] = patient;
        }
      });
  Future<void> setPatientArchived(String id, bool archived) => _commit(() {
    final i = patients.indexWhere((p) => p.id == id);
    if (i < 0) throw StateError('Patient not found.');
    patients[i] = Patient.fromJson({
      ...patients[i].toJson(),
      'recordStatus': archived ? 'archived' : 'active',
      'archivedAt': archived ? DateTime.now().toUtc().toIso8601String() : null,
      'archivedBy': archived ? actorUid : null,
    });
  });
  // Compatibility entry point now archives; no normal destructive deletion.
  Future<void> deletePatient(String id) => setPatientArchived(id, true);
  Future<void> addSchedule(
    Patient patient,
    DateTime start,
    String batch, {
    int plannedDurationMinutes = 240,
  }) async {
    var records = <NotificationDelivery>[];
    await _commit(() {
      if (!validPlannedDuration(plannedDurationMinutes)) {
        throw StateError('Planned duration must be 30–720 minutes.');
      }
      if (patientFor(patient.id).archived) {
        throw StateError('Restore the Patient before adding a new session.');
      }
      if (!patients.any((p) => p.id == patient.id)) {
        throw StateError('Patient no longer exists.');
      }
      if (sessions.any(
        (s) =>
            s.patientId == patient.id &&
            s.status != SessionStatus.cancelled &&
            s.status != SessionStatus.missed &&
            start.isBefore(
              s.start.add(Duration(minutes: s.plannedDurationMinutes ?? 720)),
            ) &&
            start
                .add(Duration(minutes: plannedDurationMinutes))
                .isAfter(s.start),
      )) {
        throw StateError('This patient already has a session at that time.');
      }
      checkSlot(patient.id, start, batch, plannedDurationMinutes);
      final id = 'S-${DateTime.now().microsecondsSinceEpoch}';
      sessions.add(
        SessionRecord(
          id: id,
          patientId: patient.id,
          start: start,
          room: patient.room,
          batch: batch,
          status: SessionStatus.pending,
          plannedDurationMinutes: plannedDurationMinutes,
          scheduleGroup: patient.scheduleGroup,
        ),
      );
      sessions.sort((a, b) => a.start.compareTo(b.start));
      notifications.insert(
        0,
        StaffNotification(
          id: 'N-$id',
          category: 'System',
          title: 'Schedule Created',
          message:
              '${patient.name} has a session scheduled on ${shortDate(start)} at ${sessionTime(start)}.',
          time: DateTime.now(),
          icon: 'reminder',
        ),
      );
      records = _enqueue(
        sessions.firstWhere((s) => s.id == id),
        NotificationType.scheduleCreated,
        '$id:created',
      );
    });
    await _dispatch(records);
  }

  Future<void> markAllRead() => _commit(() {
    notifications = notifications.map((n) => n.markRead()).toList();
    deliveryHistory = deliveryHistory
        .map((d) => d.copyWith(read: true))
        .toList();
  });
  Future<void> markRead(String id) => _commit(() {
    deliveryHistory = deliveryHistory
        .map((d) => d.id == id ? d.copyWith(read: true) : d)
        .toList();
    notifications = notifications
        .map((n) => n.id == id ? n.markRead() : n)
        .toList();
  });
  Future<bool> verifyPassword(String value) async {
    if (passwordHash.isEmpty) {
      return value.isEmpty;
    }
    final key = await compute(_passwordKey, [value, passwordSalt]);
    final a = utf8.encode(key), b = utf8.encode(passwordHash);
    var mismatch = a.length ^ b.length;
    for (var i = 0; i < a.length && i < b.length; i++) {
      mismatch |= a[i] ^ b[i];
    }
    return mismatch == 0;
  }

  Future<void> changePassword(String current, String next) async {
    if (passwordHash.isNotEmpty && !await verifyPassword(current)) {
      throw StateError('Current password is incorrect.');
    }
    if (next.length < 8) {
      throw ArgumentError('Use at least 8 characters.');
    }
    final salt = base64Encode(
      List.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final hash = await compute(_passwordKey, [next, salt]);
    await _commit(() {
      passwordSalt = salt;
      passwordHash = hash;
    });
  }

  Future<bool> signIn(String password) async {
    final valid = await verifyPassword(password);
    if (valid) {
      signedIn = true;
      _notify();
    }
    return valid;
  }

  void logOut() {
    signedIn = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

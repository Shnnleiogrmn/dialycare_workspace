import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'backend_client.dart';
import 'governance_repository.dart';
import 'account_policy.dart';
import 'session.dart';

/// Firestore REST requests carry Firebase ID tokens, so Security Rules apply.
/// This avoids requiring a second native Firebase SDK in the Windows runner.
class FirestoreRepository extends BackendClient {
  FirestoreRepository({
    required super.token,
    required this.uid,
    http.Client? client,
    this.project = 'dialycare-backend-3f0ed',
    this.emulatorHost,
    this.onFailure,
    this.clock = DateTime.now,
  }) : client = client ?? http.Client();
  final String Function() uid;
  final String project;
  final DateTime Function() clock;
  Map<String, dynamic>? _patientYearCounterDoc;
  int? _patientCounterYear;
  bool _patientYearCounterAvailable = true;
  bool _patientIdMigrationRequired = false;

  Future<void> _loadPatientYearCounter(int year) async {
    _patientCounterYear = year;
    try {
      _patientYearCounterDoc = await get('idCounters/patients-$year');
      _patientYearCounterAvailable = true;
    } on BackendException catch (failure) {
      if (failure.statusCode != 403) rethrow;
      // Preserve existing operations while an older Rules deployment is active.
      _patientYearCounterDoc = null;
      _patientYearCounterAvailable = false;
    }
  }

  /// Explicit local integration test option; production always defaults to HTTPS.
  final String? emulatorHost;
  final http.Client client;
  final void Function(FirestoreFailure)? onFailure;
  String _accountRole = 'unlinked';
  DateTime? _quotaRetryAt;
  DateTime? get quotaRetryAt => _quotaRetryAt;
  Map<String, Map<String, dynamic>> _loaded = {};
  String? _revisionTime;
  bool _staffLoaded = false;
  String? loadedStaffRole;
  List<List<Map<String, dynamic>>>? _cachedStaffRows;
  String? _cachedStaffRevision, _cachedStaffUid;
  DateTime? _cachedStaffAt;
  Map<String, dynamic>? _cachedMobile;
  String? _mobileCacheKey;
  DateTime? _mobileCacheAt;
  Map<String, dynamic>? _idCounterDoc;
  Map<String, dynamic> _counterValues = {
    'nextPatientNumber': 1,
    'nextRelativeNumber': 1,
  };
  String get root => 'projects/$project/databases/(default)/documents';
  String get url {
    if (emulatorHost != null &&
        !RegExp(r'^(127\.0\.0\.1|localhost):[0-9]+$').hasMatch(emulatorHost!)) {
      throw const BackendException(
        'Only a local Firestore emulator is allowed.',
      );
    }
    return '${emulatorHost == null ? 'https://firestore.googleapis.com' : 'http://$emulatorHost'}/v1/$root';
  }

  static dynamic canonical(dynamic value) {
    if (value is double &&
        value.isFinite &&
        value == value.truncateToDouble()) {
      return value.toInt();
    }
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      return {for (final key in keys) key: canonical(value[key])};
    }
    if (value is List) return value.map(canonical).toList();
    return value;
  }

  Future<List<Map<String, dynamic>>> sessionHistory(String id) async =>
      (await query(
        'sessionEvents',
        field: 'sessionId',
        equals: id,
      )).map(data).toList();
  static void setNested(
    Map target,
    String path,
    dynamic value, {
    bool encoded = false,
    bool remove = false,
  }) {
    final parts = path.split('.');
    Map current = target;
    for (final part in parts.take(parts.length - 1)) {
      current = encoded
          ? current[part]['mapValue']['fields'] as Map
          : current[part] as Map;
    }
    if (remove) {
      current.remove(parts.last);
    } else {
      current[parts.last] = value;
    }
  }

  void close() => client.close();

  static dynamic encode(dynamic value) {
    if (value == null) return {'nullValue': null};
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': '$value'};
    if (value is num) return {'doubleValue': value};
    if (value is String) return {'stringValue': value};
    if (value is List) {
      return {
        'arrayValue': {'values': value.map(encode).toList()},
      };
    }
    if (value is Map) {
      return {
        'mapValue': {
          'fields': value.map((k, v) => MapEntry(k.toString(), encode(v))),
        },
      };
    }
    throw const FormatException('Unsupported Firestore value');
  }

  static dynamic decode(Map value) {
    if (value.containsKey('nullValue')) return null;
    if (value.containsKey('booleanValue')) return value['booleanValue'];
    if (value.containsKey('integerValue')) {
      return int.parse(value['integerValue'].toString());
    }
    if (value.containsKey('doubleValue')) {
      return (value['doubleValue'] as num).toDouble();
    }
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('timestampValue')) return value['timestampValue'];
    if (value.containsKey('arrayValue')) {
      return ((value['arrayValue']['values'] as List?) ?? [])
          .map((v) => decode(v as Map))
          .toList();
    }
    if (value.containsKey('mapValue')) {
      return fields(value['mapValue']['fields'] as Map? ?? {});
    }
    throw const FormatException('Unsupported Firestore field');
  }

  static Map<String, dynamic> fields(Map values) =>
      values.map((k, v) => MapEntry(k.toString(), decode(v as Map)));
  Map<String, dynamic> document(String path, Map<String, dynamic> data) => {
    'name': '$root/$path',
    'fields': data.map((k, v) => MapEntry(k, encode(v))),
  };
  Future<dynamic> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    if (_quotaRetryAt case final retryAt?
        when DateTime.now().isBefore(retryAt)) {
      throw const BackendException(
        'The care center database has reached its usage limit. Automatic refresh is paused. Please contact your dialysis center and try again later.',
        429,
      );
    }
    final bearer = await token();
    if (bearer == null) throw const BackendException('Please log in.', 401);
    final req = http.Request(method, Uri.parse('$url$path'));
    req.headers.addAll({
      'Authorization': 'Bearer $bearer',
      'Content-Type': 'application/json',
    });
    if (body != null) req.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await client.send(req).timeout(const Duration(seconds: 25)),
    );
    dynamic result;
    try {
      result = jsonDecode(response.body);
    } catch (_) {
      throw const BackendException(
        'Firestore is unavailable. Please try again.',
      );
    }
    if (response.statusCode >= 400) {
      // Streaming REST endpoints may wrap the error in an array.
      final envelope = result is List && result.isNotEmpty
          ? result.first
          : result;
      final error = envelope is Map ? envelope['error'] as Map? : null;
      final status =
          error?['status'] as String? ?? 'HTTP_${response.statusCode}';
      if (response.statusCode == 429 || status == 'RESOURCE_EXHAUSTED') {
        _quotaRetryAt = DateTime.now().add(const Duration(minutes: 15));
      }
      final failure = FirestoreFailure(
        switch (response.statusCode) {
          401 => 'Your session expired. Please sign in again.',
          403 => 'Access denied. Check your approved account link and Firestore setup.',
          404 => 'The requested record or Firestore database is unavailable.',
          409 => 'The workspace changed. Refresh before saving.',
          429 => 'The care center database has reached its usage limit. Automatic refresh is paused. Please contact your dialysis center and try again later.',
          400 when status == 'INVALID_ARGUMENT' => 'This request could not be processed. Please contact your dialysis center.',
          503 => 'The care center database is temporarily unavailable. Please try again later.',
          _ =>
            status == 'FAILED_PRECONDITION'
                ? 'The workspace changed or a Firestore index is missing. Refresh and contact your administrator.'
                : 'Firestore request failed. Please try again.',
        },
        response.statusCode,
        code: status,
        operation: method,
        resources: _requestResources(path, body),
        uid: uid(),
        role: loadedStaffRole ?? _accountRole,
        firebaseMessage: (error?['message'] as String? ?? 'No Firebase message')
            .replaceAll(
              RegExp(r'invitations/[a-zA-Z0-9_-]+'),
              'invitations/[redacted]',
            ),
      );
      onFailure?.call(failure);
      if (kDebugMode) {
        debugPrint(
          jsonEncode({
            'service': 'Firestore',
            'project': project,
            'code': failure.code,
            'httpStatus': failure.statusCode,
            'operation': failure.operation,
            'resources': failure.resources,
            'uid': failure.uid,
            'role': failure.role,
            'firebaseMessage': failure.firebaseMessage,
          }),
        );
      }
      throw failure;
    }
    return result;
  }

  List<String> _requestResources(String path, Map<String, dynamic>? body) {
    String safe(String value) {
      final relative = value
          .replaceFirst('$root/', '')
          .replaceFirst(RegExp(r'^/'), '');
      // A PIN-derived lookup is a secret capability; never log it.
      return relative.startsWith('invitations/')
          ? 'invitations/[redacted]'
          : relative;
    }

    if (path == ':runQuery') {
      return [
        for (final source in body?['structuredQuery']?['from'] as List? ?? [])
          source['collectionId'] as String,
      ];
    }
    if (path == ':commit') {
      return [
        for (final write in body?['writes'] as List? ?? [])
          safe(
            (write['update']?['name'] ?? write['delete'] ?? 'unknown')
                as String,
          ),
      ];
    }
    return [safe(path)];
  }

  Future<Map<String, dynamic>?> get(String path) async {
    try {
      return Map<String, dynamic>.from(await request('GET', '/$path') as Map);
    } on BackendException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> query(
    String collection, {
    String? field,
    dynamic equals,
  }) async {
    final result = await request('POST', ':runQuery', {
      'structuredQuery': {
        'from': [
          {'collectionId': collection},
        ],
        if (field != null)
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': field},
              'op': 'EQUAL',
              'value': encode(equals),
            },
          },
      },
    }) as List;
    return [
      for (final row in result)
        if (row['document'] != null)
          Map<String, dynamic>.from(row['document'] as Map),
    ];
  }

  Map<String, dynamic> data(Map<String, dynamic> doc) =>
      fields(doc['fields'] as Map? ?? {});
  Future<Map<String, dynamic>> account() async {
    final doc = await get('users/${uid()}');
    if (doc == null) {
      throw const BackendException(
        'Your account is not linked. Contact your care center.',
        403,
      );
    }
    final value = data(doc);
    _accountRole = value['role'] as String? ?? 'unlinked';
    if (value['disabled'] != false) {
      throw const BackendException(
        'Your DialyCare access is currently disabled. Please contact your dialysis center.',
        403,
      );
    }
    if (['staff', 'admin'].contains(value['role']) &&
        value['accountStatus'] != 'active') {
      throw const BackendException(
        'Your Staff access is currently disabled or not approved. Contact your dialysis center administrator.',
        403,
      );
    }
    if (value.containsKey('activationId')) {
      final binding = await get(
        'accountBindings/${value['role']}_${value['recipientId']}',
      );
      if (binding == null ||
          data(binding)['uid'] != uid() ||
          data(binding)['accountStatus'] != 'active') {
        throw const BackendException(
          'Your DialyCare access is currently disabled or awaiting center approval. Please contact your dialysis center.',
          403,
        );
      }
    }
    return value;
  }

  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    switch (action) {
      case 'staffData':
        return loadStaff(allowCached: data['poll'] == true);
      case 'staffSave':
        return saveStaff(Map<String, dynamic>.from(data['bundle'] as Map));
      case 'mobileData':
        return loadMobile(
          data['role'] as String?,
          allowCached: data['poll'] == true,
        );
      case 'readNotification':
        _cachedMobile = null;
        await request('POST', ':commit', {
          'writes': [
            {
              'transform': {
                'document': '$root/notifications/${data['id']}',
                'fieldTransforms': [
                  {'fieldPath': 'readAt', 'setToServerValue': 'REQUEST_TIME'},
                ],
              },
            },
          ],
        });
        return {'ok': true};
      default:
        throw const BackendException(
          'Account setup and push/SMS delivery require a trusted administrator. They are unavailable in the current Spark app.',
        );
    }
  }

  Map<String, dynamic> _accountView(
    List<Map<String, dynamic>> rows,
    String role,
    String id,
  ) {
    for (final doc in rows) {
      final value = data(doc);
      if (value['role'] == role && value['recipientId'] == id) {
        return {
          'accountStatus': value['accountStatus'],
          'activatedAt': value['activatedAt'],
          'activationExpiresAt': value['activationExpiresAt'],
        };
      }
    }
    return {'accountStatus': 'notActivated', 'activatedAt': null};
  }

  Future<Map<String, dynamic>> loadStaff({bool allowCached = false}) async {
    final owner = await account();
    loadedStaffRole = owner['role'] as String;
    if (!['staff', 'admin'].contains(loadedStaffRole)) {
      throw const BackendException('Authorized staff access required.', 403);
    }
    final before = await get('clinical/state');
    final reuse =
        allowCached &&
        _cachedStaffRows != null &&
        _cachedStaffUid == uid() &&
        _cachedStaffAt != null &&
        DateTime.now().difference(_cachedStaffAt!) <
            const Duration(minutes: 5) &&
        _cachedStaffRevision == before?['updateTime'];
    final rows = reuse
        ? [
            ..._cachedStaffRows!.take(4),
            await query('notifications'),
            _cachedStaffRows![5],
            await query('accountBindings'),
            _cachedStaffRows![7],
          ]
        : await Future.wait(
            [
              'patients',
              'relatives',
              'patientRelativeLinks',
              'sessions',
              'notifications',
              'patientProfiles',
              'accountBindings',
              'batches',
            ].map((c) => query(c)),
          );
    final after = await get('clinical/state');
    // Staff sees pending expiry, never the raw PIN or its verification lookup.
    final bindings = await Future.wait(
      rows[6].map((doc) async {
        final value = data(doc);
        if (value['accountStatus'] != 'activationPending' ||
            value['activationId'] == null) {
          return doc;
        }
        final invitation = await get('invitations/${value['activationId']}');
        return document(
          'accountBindings/${value['role']}_${value['recipientId']}',
          {
            ...value,
            'activationExpiresAt': invitation == null
                ? null
                : data(invitation)['expiresAt'],
          },
        );
      }),
    );
    if (before?['updateTime'] != after?['updateTime']) {
      throw const BackendException(
        'The workspace changed while loading. Refresh again.',
        409,
      );
    }
    _cachedStaffRows = rows;
    if (!reuse) _cachedStaffAt = DateTime.now();
    _cachedStaffRevision = after?['updateTime'] as String?;
    _cachedStaffUid = uid();
    _loaded = {
      for (final list in [...rows.take(6), rows[7]])
        for (final d in list)
          (d['name'] as String).substring(root.length + 1): data(d),
    };
    _revisionTime = after?['updateTime'] as String?;
    _staffLoaded = true;
    final meta = after == null ? <String, dynamic>{} : data(after);
    _idCounterDoc = await get('idCounters/center');
    final counters = _idCounterDoc == null
        ? <String, dynamic>{}
        : data(_idCounterDoc!);
    if (_idCounterDoc == null) {
      counters['nextPatientNumber'] = meta['nextPatientNumber'] ?? 1;
      counters['nextRelativeNumber'] = meta['nextRelativeNumber'] ?? 1;
      for (final role in ['patient', 'relative']) {
        final key = role == 'patient'
            ? 'nextPatientNumber'
            : 'nextRelativeNumber';
        final prefix = role == 'patient' ? 'DC-' : 'R-';
        for (final record in rows[role == 'patient' ? 0 : 1].map(data)) {
          final label =
              record['publicId'] as String? ??
              centerIdLabel(record['id'] as String, prefix);
          if (label.startsWith(prefix)) {
            final number = int.tryParse(label.substring(prefix.length));
            if (number != null) {
              counters[key] = max(counters[key] as int, number + 1);
            }
          }
        }
      }
    }
    _counterValues = Map<String, dynamic>.from(counters);
    await _loadPatientYearCounter(clock().toLocal().year);
    _patientIdMigrationRequired = rows[0]
        .map(data)
        .any(
          (p) =>
              !RegExp(r'^DP-[1-9][0-9]{3}-[0-9]{3}$')
                  .hasMatch((p['publicId'] ?? p['id'] ?? '').toString()),
        );
    if (meta.containsKey('bundle')) {
      throw const BackendException(
        'Legacy cloud snapshot found. An administrator must migrate it before using Spark.',
      );
    }
    final patients = rows[0]
        .map(data)
        .map(
          (p) => {
            ...p,
            'mobileAccount': _accountView(
              bindings,
              'patient',
              p['id'] as String,
            ),
            'companions': [
              for (final l in rows[2].map(data))
                if (l['patientId'] == p['id'] && l['active'] == true)
                  for (final r in rows[1].map(data))
                    if (r['id'] == l['relativeId'])
                      {
                        ...r,
                        'relationship': l['relationship'],
                        'mobileAccount': _accountView(
                          bindings,
                          'relative',
                          r['id'] as String,
                        ),
                      },
            ],
          },
        )
        .toList();
    return {
      'revision': meta['revision'] ?? 0,
      'bundle': {
        'version': 2,
        'workspaceVersion': _revisionTime ?? 'initial',
        'patientNumbersByYear': {
          '$_patientCounterYear': _patientYearCounterDoc == null
              ? 1
              : data(_patientYearCounterDoc!)['nextPatientNumber'],
        },
        'nextPatientNumber':
            counters['nextPatientNumber'] ?? meta['nextPatientNumber'] ?? 1,
        'nextRelativeNumber':
            counters['nextRelativeNumber'] ?? meta['nextRelativeNumber'] ?? 1,
        'patients': patients,
        'sessions': rows[3].map(data).toList(),
        'batchConfigurations': rows[7].map(data).toList(),
        'deliveryHistory': rows[4]
            .map(data)
            .map((n) => {...n, 'read': n['staffRead'] ?? false})
            .toList(),
        'notificationEvents': meta['notificationEvents'] ?? [],
        'notifications': meta['notifications'] ?? [],
        'staffName': meta['staffName'] ?? 'Staff',
        'actorRole': loadedStaffRole,
        'actorUid': uid(),
        'publicIdLabels': {
          for (final value in [...rows[0], ...rows[1]].map(data))
            value['id'] as String:
                value['publicId'] ??
                centerIdLabel(
                  value['id'] as String,
                  ((value['id'] as String).startsWith('DC-') ||
                          (value['id'] as String).startsWith('DP-'))
                      ? 'DC-'
                      : 'R-',
                ),
          for (final link in rows[2].map(data))
            '${link['relativeId']}_${link['patientId']}':
                '${rows[1].map(data).where((r) => r['id'] == link['relativeId']).firstOrNull?['publicId'] ?? 'Relative'} / ${rows[0].map(data).where((p) => p['id'] == link['patientId']).firstOrNull?['publicId'] ?? centerIdLabel(link['patientId'] as String, 'DC-')}',
        },
        'centerInformation': await loadCenterInformation(),
      },
    };
  }

  Future<Map<String, dynamic>> saveStaff(Map<String, dynamic> bundle) async {
    if (!_staffLoaded) {
      throw const BackendException('Load the shared workspace before saving.');
    }
    final next = <String, Map<String, dynamic>>{};
    for (final b in bundle['batchConfigurations'] as List? ?? []) {
      next['batches/${b['id']}'] = Map<String, dynamic>.from(b as Map);
    }
    final counters = _idCounterDoc == null
        ? _counterValues
        : data(_idCounterDoc!);
    var nextPatient = counters['nextPatientNumber'] as int? ?? 1;
    final registrationYear = clock().toLocal().year;
    if (_patientCounterYear != registrationYear) {
      await _loadPatientYearCounter(registrationYear);
    }
    var nextYearPatient = _patientYearCounterDoc == null
        ? 1
        : data(_patientYearCounterDoc!)['nextPatientNumber'] as int;
    var allocatedYearPatient = false;
    var nextRelative = counters['nextRelativeNumber'] as int? ?? 1;
    final reservations = <Map<String, dynamic>>[];
    String assignId(
      String role,
      String internalId,
      Map<String, dynamic> value,
    ) {
      final collection = role == 'patient' ? 'patients' : 'relatives';
      final previous = _loaded['$collection/$internalId'];
      final existing = previous?['publicId'] as String?;
      if (existing != null && existing.isNotEmpty) {
        if (value['publicId'] != null &&
            value['publicId'] != '' &&
            value['publicId'] != existing) {
          throw const BackendException(
            'Center-issued IDs cannot be changed. Refresh the Patient record.',
            409,
          );
        }
        return existing;
      }
      final prefix = role == 'patient' ? 'DC-' : 'R-';
      final legacy = previous != null && role == 'patient'
          ? centerIdLabel(internalId, prefix)
          : 'Not assigned';
      if (role == 'patient' && previous != null && legacy == 'Not assigned') {
        throw const BackendException(
          'This legacy Patient has no issued ID. An administrator must review its original registration before assigning one.',
          409,
        );
      }
      if (role == 'patient' && !_patientYearCounterAvailable) {
        throw const BackendException(
          'New Patient registration requires the reviewed yearly-ID Firestore Rules update. Contact your administrator.',
        );
      }
      if (role == 'patient' && _patientIdMigrationRequired) {
        throw const BackendException(
          'New Patient registration is paused until the reviewed canonical Patient ID migration is approved and completed. Existing records remain available.',
        );
      }
      final publicId = legacy != 'Not assigned'
          ? legacy
          : role == 'patient'
          ? yearlyPatientId(registrationYear, nextYearPatient)
          : sequentialCenterId(prefix, nextRelative);
      if (value['publicId'] != null &&
          value['publicId'] != '' &&
          value['publicId'] != publicId) {
        throw const BackendException(
          'Another Staff member assigned an ID. Refresh and save again.',
          409,
        );
      }
      if (role == 'patient' && patientIdYear(publicId) != null) {
        nextYearPatient++;
        allocatedYearPatient = true;
      } else if (role == 'patient') {
        nextPatient = max(
          nextPatient,
          int.parse(publicId.substring(prefix.length)) + 1,
        );
      } else if (role == 'relative') {
        nextRelative = max(
          nextRelative,
          int.parse(publicId.substring(prefix.length)) + 1,
        );
      }
      reservations.add({
        'update': document('publicIds/$publicId', {
          'role': role,
          'internalId': internalId,
          'publicId': publicId,
          if (role == 'patient' && patientIdYear(publicId) != null) ...{
            'year': registrationYear,
            'sequence': patientIdSequence(publicId),
          },
        }),
        'currentDocument': {'exists': false},
      });
      return publicId;
    }

    for (final raw in bundle['patients'] as List) {
      final id = (raw as Map)['id'] as String;
      // A typed form must not erase older clinical fields it does not edit.
      final p = <String, dynamic>{
        ...?_loaded['patients/$id'],
        ...Map<String, dynamic>.from(raw),
      };
      p['publicId'] = assignId('patient', id, p);
      final relatives = p.remove('companions') as List? ?? [];
      p.remove('registration');
      p.remove('mobileAccount');
      final previous = _loaded['patients/$id'];
      if (previous != null) {
        for (final entry in const <String, dynamic>{
          'maritalStatus': 'Unknown',
          'philHealthNumber': '',
          'heightCm': null,
          'weightKg': null,
          'mdrStatus': 'Unknown',
          'time': '',
          'suffix': '',
          'status': 'Pending',
          'bloodType': '',
          'medicalNotes': '',
          'treatmentNotes': '',
        }.entries) {
          if (!previous.containsKey(entry.key) && p[entry.key] == entry.value) {
            p.remove(entry.key);
          }
        }
      }
      final oldBirth = previous?['birthDate'] as String?;
      final newBirth = p['birthDate'] as String?;
      if (oldBirth != null &&
          newBirth != null &&
          DateTime.tryParse(oldBirth)
                  ?.isAtSameMomentAs(DateTime.parse(newBirth)) ==
              true) {
        p['birthDate'] = oldBirth;
      }
      next['patients/$id'] = p;
      // Safe coordination projection; relatives never receive clinical/contact fields.
      next['patientProfiles/$id'] = {
        'id': id,
        'name': p['name'],
        'publicId': p['publicId'],
        if (p['scheduleGroup'] != null) 'scheduleGroup': p['scheduleGroup'],
        'syncVersion': ?_loaded['patientProfiles/$id']?['syncVersion'],
      };
      for (final raw in relatives) {
        final relative = Map<String, dynamic>.from(raw as Map),
            rid = relative['id'] as String;
        final relationship = relative.remove('relationship');
        relative['publicId'] = assignId('relative', rid, relative);
        relative.remove('registration');
        relative.remove('mobileAccount');
        next['relatives/$rid'] = relative;
        next['patientRelativeLinks/${rid}_$id'] = {
          'relativeId': rid,
          'patientId': id,
          'relationship': relationship,
          'active': true,
        };
      }
    }
    for (final s in bundle['sessions'] as List) {
      final path = 'sessions/${s['id']}';
      final value = Map<String, dynamic>.from(s as Map),
          previous = _loaded[path];
      for (final field in [
        'start',
        'expectedEnd',
        'actualStartedAt',
        'completedAt',
        'endedAt',
      ]) {
        final oldTime = previous?[field] as String?,
            newTime = value[field] as String?;
        if (oldTime != null &&
            ((field == 'actualStartedAt' ||
                    field == 'completedAt' ||
                    field == 'endedAt') ||
                (newTime != null &&
                    DateTime.tryParse(oldTime)
                            ?.isAtSameMomentAs(DateTime.parse(newTime)) ==
                        true))) {
          value[field] = oldTime;
        }
      }
      final intervals = value['pauseIntervals'] as Map?;
      final oldIntervals = previous?['pauseIntervals'] as Map? ?? {};
      if (intervals != null) {
        for (final key in intervals.keys) {
          for (final field in ['pausedAt', 'resumedAt']) {
            if (oldIntervals[key]?[field] != null) {
              intervals[key][field] = oldIntervals[key][field];
            }
          }
        }
      }
      next[path] = value;
    }
    for (final n in bundle['deliveryHistory'] as List) {
      final notification = Map<String, dynamic>.from(n as Map);
      notification.remove(
        'readAt',
      ); // Only the recipient's acknowledgment owns this field.
      notification['staffRead'] = notification.remove('read') ?? false;
      final old = _loaded['notifications/${n['id']}'];
      if (old != null) notification['createdAt'] = old['createdAt'];
      notification['recipientKey'] =
          '${n['recipientType']}:${n['recipientId']}:${n['patientId']}';
      next['notifications/${n['id']}'] = notification;
    }
    for (final entry in _loaded.entries) {
      if (entry.key.startsWith('relatives/') && !next.containsKey(entry.key)) {
        next[entry.key] = entry.value;
      }
      if (entry.key.startsWith('patientRelativeLinks/') &&
          !next.containsKey(entry.key)) {
        next[entry.key] = {...entry.value, 'active': false};
      }
    }
    // A nonclinical revision avoids repeatedly downloading unchanged histories.
    final affected = <String>{};
    dynamic coordinationValue(String path, Map<String, dynamic>? value) {
      if (value == null) return null;
      final clean = Map<String, dynamic>.from(value);
      if (path.startsWith('notifications/')) clean.remove('readAt');
      if (path.startsWith('patients/')) {
        clean.remove('createdAt');
        clean.remove('updatedAt');
      }
      return canonical(clean);
    }

    for (final entry in {..._loaded, ...next}.entries) {
      if (jsonEncode(coordinationValue(entry.key, _loaded[entry.key])) ==
          jsonEncode(coordinationValue(entry.key, next[entry.key]))) {
        continue;
      }
      if (entry.key.startsWith('patients/')) {
        affected.add(entry.key.split('/').last);
      }
      if (entry.key.startsWith('sessions/') ||
          entry.key.startsWith('notifications/') ||
          entry.key.startsWith('patientRelativeLinks/')) {
        final pid = (next[entry.key] ?? entry.value)['patientId'];
        if (pid is String) affected.add(pid);
      }
      if (entry.key.startsWith('relatives/')) {
        final rid = entry.key.split('/').last;
        for (final link in next.entries.where(
          (v) =>
              v.key.startsWith('patientRelativeLinks/') &&
              v.value['relativeId'] == rid,
        )) {
          affected.add(link.value['patientId'] as String);
        }
      }
    }
    for (final entry in next.entries.where(
      (v) => v.key.startsWith('patientProfiles/'),
    )) {
      if (affected.contains(entry.value['id']) ||
          entry.value['syncVersion'] == null) {
        entry.value['syncVersion'] = List.generate(
          16,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
      }
    }
    final writes = <Map<String, dynamic>>[];
    int? counterWriteIndex, patientYearWriteIndex;
    if (allocatedYearPatient) {
      patientYearWriteIndex = writes.length;
      writes.add({
        'update': document('idCounters/patients-$registrationYear', {
          'year': registrationYear,
          'nextPatientNumber': nextYearPatient,
        }),
        'currentDocument': _patientYearCounterDoc == null
            ? {'exists': false}
            : {'updateTime': _patientYearCounterDoc!['updateTime']},
      });
    }
    if (reservations.isNotEmpty || _idCounterDoc == null) {
      writes.addAll(reservations);
      counterWriteIndex = writes.length;
      writes.add({
        'update': document('idCounters/center', {
          'nextPatientNumber': nextPatient,
          'nextRelativeNumber': nextRelative,
        }),
        'currentDocument': _idCounterDoc == null
            ? {'exists': false}
            : {'updateTime': _idCounterDoc!['updateTime']},
      });
    }
    final changedPatients = <String, int>{};
    final changedSessionTimes = <String, ({int index, List<String> fields})>{};
    final auditWrites = <Map<String, dynamic>>[];
    void audit(String action, String type, String id) => auditWrites.add(
      auditWrite(action, type, id, actorRole: loadedStaffRole!),
    );
    for (final entry in next.entries) {
      final previous = _loaded[entry.key];
      final patientRecord = entry.key.startsWith('patients/');
      if (entry.key.startsWith('sessions/')) {
        // A caller may still hold its provisional local timestamps. Preserve
        // the acknowledged server values in both the payload and next cache.
        for (final field in ['actualStartedAt', 'completedAt', 'endedAt']) {
          if (previous?[field] != null) entry.value[field] = previous![field];
        }
      }
      if (patientRecord) {
        // Audit times come from Firestore, never from a client form's clock.
        if (entry.value['recordStatus'] == 'archived' &&
            previous?['recordStatus'] == 'archived') {
          entry.value['archivedAt'] = previous?['archivedAt'];
          entry.value['archivedBy'] = previous?['archivedBy'];
        }
        for (final field in ['createdAt', 'updatedAt']) {
          entry.value.remove(field);
          if (previous?[field] != null) entry.value[field] = previous![field];
        }
      }
      final cleanPrevious = previous == null
          ? null
          : (Map<String, dynamic>.from(previous)..remove('readAt'));
      if (jsonEncode(canonical(cleanPrevious)) ==
          jsonEncode(canonical(entry.value))) {
        continue;
      }
      final id = entry.key.split('/').last;
      if (patientRecord) {
        final archived = entry.value['recordStatus'] == 'archived';
        final wasArchived = previous?['recordStatus'] == 'archived';
        audit(
          previous == null
              ? 'patientCreated'
              : archived != wasArchived
              ? (archived ? 'patientArchived' : 'patientRestored')
              : 'patientUpdated',
          'patient',
          id,
        );
        if (archived != wasArchived) {
          entry.value['archivedBy'] = archived ? uid() : null;
        }
      } else if (entry.key.startsWith('relatives/')) {
        audit(
          previous == null ? 'relativeCreated' : 'relativeUpdated',
          'relative',
          id,
        );
      } else if (entry.key.startsWith('patientRelativeLinks/')) {
        if (previous?['active'] != entry.value['active']) {
          audit(
            entry.value['active'] == true
                ? 'relativeLinked'
                : 'relativeUnlinked',
            'relativeLink',
            id,
          );
        }
      } else if (entry.key.startsWith('sessions/')) {
        if (previous == null ||
            ['start', 'batch', 'room', 'plannedDurationMinutes'].any(
              (field) =>
                  (field == 'start'
                      ? DateTime.tryParse(previous[field]?.toString() ?? '')
                      : canonical(previous[field])) !=
                  (field == 'start'
                      ? DateTime.tryParse(entry.value[field]?.toString() ?? '')
                      : canonical(entry.value[field])),
            )) {
          Map<String, dynamic> schedule(Map<String, dynamic> v) => {
            for (final field in [
              'start',
              'batch',
              'room',
              'plannedDurationMinutes',
            ])
              field: v[field],
          };
          final historyId = List.generate(
            16,
            (_) =>
                Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
          ).join();
          writes.add({
            'update': document('scheduleHistory/$historyId', {
              'id': historyId,
              'patientId': entry.value['patientId'],
              'sessionId': id,
              'before': previous == null ? null : schedule(previous),
              'after': schedule(entry.value),
            }),
            'currentDocument': {'exists': false},
            'updateTransforms': [
              {'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'},
            ],
          });
        }
        if (previous == null ||
            previous['start'] != entry.value['start'] ||
            previous['plannedDurationMinutes'] !=
                entry.value['plannedDurationMinutes']) {
          final s = SessionRecord.fromJson(entry.value);
          for (final other in next.entries.where(
            (e) =>
                e.key.startsWith('sessions/') &&
                e.key != entry.key &&
                e.value['patientId'] == s.patientId,
          )) {
            final o = SessionRecord.fromJson(other.value);
            if (o.status == SessionStatus.cancelled ||
                o.status == SessionStatus.missed ||
                s.status == SessionStatus.cancelled ||
                s.status == SessionStatus.missed) {
              continue;
            }
            if (s.start.isBefore(
                  o.start.add(
                    Duration(minutes: o.plannedDurationMinutes ?? 720),
                  ),
                ) &&
                s.start
                    .add(Duration(minutes: s.plannedDurationMinutes ?? 720))
                    .isAfter(o.start)) {
              throw const BackendException(
                'This Patient already has an overlapping appointment.',
              );
            }
          }
        }
        if (previous == null) {
          final pid = entry.value['patientId'];
          if (next['patients/$pid']?['recordStatus'] == 'archived') {
            throw const BackendException(
              'Restore the Patient before adding a new session.',
            );
          }
        }
        audit(
          previous == null
              ? 'sessionCreated'
              : previous['status'] != entry.value['status']
              ? 'sessionStatusChanged'
              : 'sessionEdited',
          'session',
          id,
        );
      } else if (entry.key.startsWith('batches/')) {
        audit('centerSettingsChanged', 'settings', id);
      } else if (entry.key.startsWith('notifications/') &&
          previous == null &&
          entry.value['trigger'] == 'staff') {
        audit('reminderCreated', 'notification', id);
      }
      if (entry.key.startsWith('sessions/') &&
          previous != null &&
          previous['status'] != entry.value['status']) {
        final from = SessionStatus.fromStorage(previous['status'] as String),
            to = SessionStatus.fromStorage(entry.value['status'] as String);
        if (!sessionTransitionAllowed(from, to)) {
          throw const BackendException('Invalid session transition.');
        }
        final revision = entry.value['revision'] as int;
        final drafts = bundle['sessionEvents'] as List? ?? [];
        final draft = drafts
            .where((e) => e['sessionId'] == id && e['revision'] == revision)
            .firstOrNull;
        final type = to == SessionStatus.inProgress
            ? (from == SessionStatus.paused ? 'RESUME' : 'START')
            : to == SessionStatus.paused
            ? 'PAUSE'
            : to == SessionStatus.completed
            ? 'COMPLETE'
            : to == SessionStatus.endedEarly
            ? 'END_EARLY'
            : to == SessionStatus.cancelled
            ? 'CANCEL'
            : 'STATUS';
        final event = document('sessionEvents/${id}_$revision', {
          'id': '${id}_$revision',
          'sessionId': id,
          'patientId': entry.value['patientId'],
          'revision': revision,
          'fromStatus': from.label,
          'toStatus': to.label,
          'type': type,
          'actorUid': uid(),
          'reasonCode': draft?['reasonCode'] ?? '',
          'note': draft?['note'] ?? '',
        });
        auditWrites.add({
          'update': event,
          'currentDocument': {'exists': false},
          'updateTransforms': [
            {'fieldPath': 'timestamp', 'setToServerValue': 'REQUEST_TIME'},
          ],
        });
      }
      final notification = entry.key.startsWith('notifications/');
      final sessionRecord = entry.key.startsWith('sessions/');
      final sessionTransforms = <String>[];
      if (sessionRecord) {
        if (entry.value['status'] == 'In Progress' &&
            previous?['actualStartedAt'] == null) {
          sessionTransforms.add('actualStartedAt');
        }
        if (entry.value['status'] == 'Completed' &&
            previous?['completedAt'] == null &&
            previous?['status'] != 'Completed') {
          sessionTransforms.add('completedAt');
        }
        if (['Ended Early', 'Cancelled'].contains(entry.value['status']) &&
            previous?['endedAt'] == null) {
          sessionTransforms.add('endedAt');
        }
        final intervals = entry.value['pauseIntervals'] as Map? ?? {};
        final oldIntervals = previous?['pauseIntervals'] as Map? ?? {};
        for (final key in intervals.keys) {
          for (final field in ['pausedAt', 'resumedAt']) {
            if (intervals[key][field] != null &&
                oldIntervals[key]?[field] == null) {
              sessionTransforms.add('pauseIntervals.$key.$field');
            }
          }
        }
      }
      final value = {
        ...entry.value,
        if (notification && previous == null) 'readAt': null,
      };
      final updatedDocument = document(
        entry.key,
        notification && previous != null
            ? {
                'attempts': entry.value['attempts'],
                'staffRead': entry.value['staffRead'],
              }
            : value,
      );
      if (patientRecord) {
        changedPatients[entry.key] = writes.length;
        final fields = updatedDocument['fields'] as Map;
        fields.remove('updatedAt');
        if (entry.value['recordStatus'] == 'archived' &&
            previous?['recordStatus'] == 'archived' &&
            previous?['archivedAt'] != null) {
          fields['archivedAt'] = {'timestampValue': previous!['archivedAt']};
        }
        if (entry.value['recordStatus'] == 'archived' &&
            previous?['recordStatus'] != 'archived') {
          fields.remove('archivedAt');
        }
        if (previous?['createdAt'] != null) {
          fields['createdAt'] = {'timestampValue': previous!['createdAt']};
        } else {
          fields.remove('createdAt');
        }
      }
      if (sessionRecord) {
        final fields = updatedDocument['fields'] as Map;
        for (final field in ['actualStartedAt', 'completedAt', 'endedAt']) {
          if (previous?[field] != null) {
            fields[field] = {'timestampValue': previous![field]};
          }
        }
        final intervals = entry.value['pauseIntervals'] as Map? ?? {};
        final oldIntervals = previous?['pauseIntervals'] as Map? ?? {};
        for (final key in intervals.keys) {
          for (final field in ['pausedAt', 'resumedAt']) {
            if (oldIntervals[key]?[field] != null) {
              setNested(fields, 'pauseIntervals.$key.$field', {
                'timestampValue': oldIntervals[key][field],
              }, encoded: true);
            }
          }
        }
        for (final field in sessionTransforms) {
          setNested(fields, field, null, encoded: true, remove: true);
        }
        if (sessionTransforms.isNotEmpty) {
          changedSessionTimes[entry.key] = (
            index: writes.length,
            fields: sessionTransforms,
          );
        }
      }
      writes.add({
        'update': updatedDocument,
        if (notification && previous != null)
          'updateMask': {
            'fieldPaths': ['attempts', 'staffRead'],
          },
        if (notification && previous == null)
          'updateTransforms': [
            {'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'},
          ],
        if (patientRecord)
          'updateTransforms': [
            if (previous == null)
              {'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'},
            {'fieldPath': 'updatedAt', 'setToServerValue': 'REQUEST_TIME'},
            if (entry.value['recordStatus'] == 'archived' &&
                previous?['recordStatus'] != 'archived')
              {'fieldPath': 'archivedAt', 'setToServerValue': 'REQUEST_TIME'},
          ],
        if (sessionTransforms.isNotEmpty)
          'updateTransforms': [
            for (final field in sessionTransforms)
              {'fieldPath': field, 'setToServerValue': 'REQUEST_TIME'},
          ],
      });
    }
    for (final path in _loaded.keys) {
      if (!next.containsKey(path)) {
        if (path.startsWith('sessions/') ||
            path.startsWith('patients/') ||
            path.startsWith('patientProfiles/')) {
          throw const BackendException(
            'Archive Patients instead of deleting care records.',
          );
        }
        writes.add({'delete': '$root/$path'});
        if (path.startsWith('sessions/')) {
          audit('sessionRemoved', 'session', path.split('/').last);
        }
      }
    }
    for (final raw in bundle['patients'] as List) {
      final p = raw as Map;
      if (!affected.contains(p['id']) &&
          _loaded.containsKey('patients/${p['id']}')) {
        continue;
      }
      final relatives = p['companions'] as List? ?? [];
      final relative = relatives.isEmpty
          ? <String, dynamic>{}
          : relatives.first as Map;
      writes.add({
        'update': document('patientAccountProfiles/${p['id']}', {
          'id': p['id'],
          'contact': p['contact'] ?? '',
          'gender': p['gender'] ?? '',
          'relativeName': relative['name'] ?? '',
          'relationship': relative['relationship'] ?? '',
        }),
      });
    }
    writes.add({
      'update': document('clinical/state', {
        'revision': DateTime.now().microsecondsSinceEpoch,
        'staffName': bundle['staffName'],
        'nextPatientNumber': nextPatient,
        'nextRelativeNumber': nextRelative,
        'notifications': bundle['notifications'],
        'notificationEvents': bundle['notificationEvents'],
      }),
      'currentDocument': _revisionTime == null
          ? {'exists': false}
          : {'updateTime': _revisionTime},
    });
    final revisionIndex = writes.length - 1;
    writes.addAll(auditWrites);
    if (writes.length > 450) {
      throw const BackendException(
        'This change is too large for one atomic save. Save fewer changes at a time.',
      );
    }
    final result = await request('POST', ':commit', {'writes': writes}) as Map;
    // A failed follow-up read must never turn a committed write into a rollback.
    _revisionTime =
        (result['writeResults'] as List)[revisionIndex]['updateTime'] as String;
    for (final entry in changedSessionTimes.entries) {
      final stamps =
          (result['writeResults']
                  as List)[entry.value.index]['transformResults']
              as List;
      for (var i = 0; i < entry.value.fields.length; i++) {
        setNested(
          next[entry.key]!,
          entry.value.fields[i],
          stamps[i]['timestampValue'],
        );
      }
    }
    for (final entry in changedPatients.entries) {
      final stamps =
          (result['writeResults'] as List)[entry.value]['transformResults']
              as List;
      if (!_loaded.containsKey(entry.key)) {
        next[entry.key]!['createdAt'] = stamps.first['timestampValue'];
      }
      next[entry.key]!['updatedAt'] =
          stamps[_loaded.containsKey(entry.key) ? 0 : 1]['timestampValue'];
      if (next[entry.key]!['recordStatus'] == 'archived' &&
          _loaded[entry.key]?['recordStatus'] != 'archived') {
        next[entry.key]!['archivedAt'] = stamps.last['timestampValue'];
      }
    }
    for (final entry in next.entries.where(
      (e) => e.key.startsWith('notifications/'),
    )) {
      entry.value['readAt'] = _loaded[entry.key]?['readAt'];
      if (!_loaded.containsKey(entry.key)) {
        entry.value['createdAt'] = result['commitTime'];
      }
    }
    _loaded = next;
    _counterValues = {
      'nextPatientNumber': nextPatient,
      'nextRelativeNumber': nextRelative,
    };
    if (counterWriteIndex != null) {
      _idCounterDoc = {
        ...document('idCounters/center', {
          'nextPatientNumber': nextPatient,
          'nextRelativeNumber': nextRelative,
        }),
        'updateTime':
            (result['writeResults'] as List)[counterWriteIndex]['updateTime'],
      };
    }
    if (patientYearWriteIndex != null) {
      _patientYearCounterDoc = {
        ...document('idCounters/patients-$registrationYear', {
          'year': registrationYear,
          'nextPatientNumber': nextYearPatient,
        }),
        'updateTime':
            (result['writeResults']
                as List)[patientYearWriteIndex]['updateTime'],
      };
    }
    _cachedStaffRows = null;
    return {
      'revision': DateTime.now().microsecondsSinceEpoch,
      'workspaceVersion': _revisionTime,
      'sessions': next.entries
          .where((e) => e.key.startsWith('sessions/'))
          .map((e) => e.value)
          .toList(),
    };
  }

  Future<Map<String, dynamic>> loadMobile(
    String? expectedRole, {
    bool allowCached = false,
  }) async {
    final user = await account(), role = user['role'] as String;
    if (!['patient', 'relative'].contains(role) ||
        expectedRole != null && role != expectedRole) {
      throw const BackendException(
        'Use the role assigned to your account.',
        403,
      );
    }
    final pid = user['patientId'] as String,
        rid = user['recipientId'] as String;
    Map<String, dynamic>? profile;
    try {
      profile = await get('patientProfiles/$pid');
    } on BackendException catch (e) {
      if (e.statusCode != 403 || role != 'relative') rethrow;
      throw const BackendException(
        'This Relative account is not currently authorized for this Patient. Please contact your dialysis center.',
        403,
      );
    }
    if (profile == null) {
      throw const BackendException(
        'Your patient record is unavailable. Contact your care center.',
        403,
      );
    }
    final version = data(profile)['syncVersion'];
    final cacheKey = '${uid()}:$role:$pid:$rid:$version';
    if (allowCached &&
        version is String &&
        _cachedMobile != null &&
        _mobileCacheKey == cacheKey &&
        _mobileCacheAt != null &&
        DateTime.now().difference(_mobileCacheAt!) <
            const Duration(minutes: 5)) {
      final updates =
          (await query(
            'notifications',
            field: 'recipientKey',
            equals: '$role:$rid:$pid',
          )).map(data).toList()..sort(
            (a, b) =>
                (b['createdAt'] as String).compareTo(a['createdAt'] as String),
          );
      _cachedMobile!['notifications'] = updates;
      return jsonDecode(jsonEncode(_cachedMobile)) as Map<String, dynamic>;
    }
    final relative = role == 'relative' ? await get('relatives/$rid') : null;
    final privateProfile = role == 'patient'
        ? await get('patientAccountProfiles/$pid')
        : null;
    final ownLink = role == 'relative'
        ? await get('patientRelativeLinks/${rid}_$pid')
        : null;
    final results = await Future.wait([
      query('sessions', field: 'patientId', equals: pid),
      query('notifications', field: 'recipientKey', equals: '$role:$rid:$pid'),
    ]);
    final history = results[1].map(data).toList()
      ..sort(
        (a, b) =>
            (b['createdAt'] as String).compareTo(a['createdAt'] as String),
      );
    final result = <String, dynamic>{
      'profile': {
        'role': role,
        'name': role == 'patient'
            ? data(profile)['name']
            : relative == null
            ? ''
            : data(relative)['name'],
        'patientId': data(profile)['publicId'] ?? centerIdLabel(pid, 'DC-'),
        'patientName': data(profile)['name'],
        'scheduleGroup': data(profile)['scheduleGroup'],
        if (role == 'patient')
          'gender': privateProfile == null
              ? ''
              : data(privateProfile)['gender'] ?? '',
        'accountId': role == 'patient'
            ? data(profile)['publicId'] ?? centerIdLabel(pid, 'DC-')
            : relative == null
            ? 'Not assigned'
            : data(relative)['publicId'] ?? centerIdLabel(rid, 'R-'),
        'contact': role == 'patient'
            ? (privateProfile == null
                  ? ''
                  : data(privateProfile)['contact'] ?? '')
            : (relative == null ? '' : data(relative)['contact'] ?? ''),
        'relationship': ownLink == null
            ? ''
            : data(ownLink)['relationship'] ?? '',
        'relativeName': privateProfile == null
            ? ''
            : data(privateProfile)['relativeName'] ?? '',
        'relativeRelationship': privateProfile == null
            ? ''
            : data(privateProfile)['relationship'] ?? '',
      },
      'sessions': results[0].map(data).toList(),
      'notifications': history,
    };
    _cachedMobile = result;
    _mobileCacheKey = cacheKey;
    _mobileCacheAt = DateTime.now();
    return jsonDecode(jsonEncode(result)) as Map<String, dynamic>;
  }
}

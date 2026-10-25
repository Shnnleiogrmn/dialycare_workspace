import 'dart:math';

import 'backend_client.dart';
import 'firestore_repository.dart';

const concernTypes = [
  'Feedback',
  'Complaint',
  'Service Concern',
  'Application/System Issue',
  'Schedule Concern',
  'Other',
];
const concernAreas = [
  'Schedule',
  'Session',
  'Notification',
  'Account',
  'Mobile Application',
  'Staff/Service',
  'Other',
];
const concernStatuses = ['Submitted', 'Under Review', 'Resolved', 'Closed'];

bool concernTransition(String from, String to) =>
    concernStatuses.contains(from) &&
    concernStatuses.indexOf(to) == concernStatuses.indexOf(from) + 1;

String newConcernId() =>
    'FC-${List.generate(10, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';

void validateConcern(String type, String subject, String message, String area) {
  if (!concernTypes.contains(type) ||
      !concernAreas.contains(area) ||
      subject.trim().isEmpty ||
      subject.trim().length > 120 ||
      message.trim().isEmpty ||
      message.trim().length > 2000) {
    throw const BackendException(
      'Select a type and area, enter a subject (1–120 characters) and a message (1–2000 characters).',
    );
  }
}

class FeedbackConcern {
  FeedbackConcern(
    this.values, {
    this.version,
    this.submitter = '',
    this.patient = '',
  });
  final Map<String, dynamic> values;
  final String? version;
  final String submitter, patient;
  String get id => values['concernId'] as String;
  String get status => values['status'] as String;
  String get subject => values['subject'] as String;
  String get type => values['concernType'] as String;
  String get role => values['submittedByRole'] == 'patient'
      ? 'Patient'
      : 'Designated Relative';
}

abstract class ConcernService {
  Future<List<FeedbackConcern>> list();
  Future<void> submit(
    String id,
    String type,
    String subject,
    String message,
    String area,
  );
  Future<List<Map<String, dynamic>>> responses(FeedbackConcern concern);
  Future<void> update(
    FeedbackConcern concern, {
    String? status,
    String? response,
  });
}

/// Uses the same ID-token-authenticated Firestore transport as care records.
/// Identity is read from the trusted mapping, never supplied by a form.
class FirestoreConcernService implements ConcernService {
  FirestoreConcernService(this.repository);
  final FirestoreRepository repository;
  bool _staff(Map a) => ['staff', 'admin'].contains(a['role']);
  @override
  Future<List<FeedbackConcern>> list() async {
    final a = await repository.account();
    final staff = _staff(a);
    final ownProfile = staff
        ? <String, dynamic>{}
        : repository.data(
            await repository.get('patientProfiles/${a['patientId']}') ?? {},
          );
    final docs = await repository.query(
      'feedbackConcerns',
      field: staff ? null : 'submittedByUid',
      equals: staff ? null : repository.uid(),
    );
    final names = <String, Map<String, dynamic>>{};
    Future<Map<String, dynamic>> identity(String path) async =>
        names[path] ??= repository.data(await repository.get(path) ?? {});
    final result = <FeedbackConcern>[];
    for (final doc in docs) {
      final v = repository.data(doc);
      final p = staff
          ? await identity('patients/${v['patientId']}')
          : ownProfile;
      final r = staff && v['submittedByRole'] == 'relative'
          ? await identity('relatives/${v['relativeId']}')
          : p;
      result.add(
        FeedbackConcern(
          v,
          version: doc['updateTime'] as String?,
          submitter: r['name'] as String? ?? 'Authenticated account',
          patient:
              '${p['name'] ?? 'Your linked Patient'}${p['publicId'] == null ? '' : ' • ${p['publicId']}'}',
        ),
      );
    }
    result.sort(
      (a, b) => (b.values['createdAt'] as String).compareTo(
        a.values['createdAt'] as String,
      ),
    );
    return result;
  }

  Map<String, dynamic> _write(
    String path,
    Map<String, dynamic> fields,
    List<String> stamps,
    Map<String, dynamic> precondition, {
    bool patch = false,
  }) => {
    'update': repository.document(path, fields),
    if (patch) 'updateMask': {'fieldPaths': fields.keys.toList()},
    'currentDocument': precondition,
    'updateTransforms': [
      for (final f in stamps)
        {'fieldPath': f, 'setToServerValue': 'REQUEST_TIME'},
    ],
  };

  @override
  Future<void> submit(
    String id,
    String type,
    String subject,
    String message,
    String area,
  ) async {
    validateConcern(type, subject, message, area);
    final a = await repository.account();
    if (!['patient', 'relative'].contains(a['role'])) {
      throw const BackendException(
        'Only an authorized Patient or Relative can submit a concern.',
        403,
      );
    }
    // Recheck the current authorized projection/link before writing; Rules also
    // enforce this atomically, including revocation after this read.
    await repository.get('patientProfiles/${a['patientId']}');
    final value = <String, dynamic>{
      'concernId': id,
      'submittedByUid': repository.uid(),
      'submittedByRole': a['role'],
      'patientId': a['patientId'],
      'relativeId': a['role'] == 'relative' ? a['recipientId'] : null,
      'concernType': type,
      'relatedArea': area,
      'subject': subject.trim(),
      'message': message.trim(),
      'status': 'Submitted',
      'resolvedAt': null,
      'closedAt': null,
      'revision': 0,
      'responseCount': 0,
      'lastResponseId': '',
      'updatedBy': repository.uid(),
    };
    try {
      await repository.request('POST', ':commit', {
        'writes': [
          _write(
            'feedbackConcerns/$id',
            value,
            ['createdAt', 'updatedAt'],
            {'exists': false},
          ),
          _write(
            'notifications/concern_submitted_$id',
            {
              'id': 'concern_submitted_$id',
              'eventId': 'concern_submitted_$id',
              'patientId': a['patientId'],
              'recipientId': 'staff',
              'recipientType': 'staff',
              'recipientName': 'Staff',
              'recipientKey': 'staff:all',
              'type': 'concernSubmitted',
              'title': 'New Feedback & Concern',
              'message': 'New Feedback & Concern submitted. Open the inbox to review it.',
              'trigger': 'automatic',
              'sessionId': '',
              'attempts': [],
              'readAt': null,
              'staffRead': false,
            },
            ['createdAt'],
            {'exists': false},
          ),
        ],
      });
    } on BackendException {
      // A retry after a lost acknowledgement uses the same form-generated ID.
      // Accept only the identical already-owned submission, never a collision.
      final existing = await repository.get('feedbackConcerns/$id');
      final stored = existing == null
          ? <String, dynamic>{}
          : repository.data(existing);
      if (value.entries.any(
        (e) =>
            ![
              'status',
              'revision',
              'responseCount',
              'lastResponseId',
              'updatedBy',
              'resolvedAt',
              'closedAt',
            ].contains(e.key) &&
            stored[e.key] != e.value,
      )) {
        rethrow;
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> responses(FeedbackConcern concern) async {
    await repository.account();
    // Read parent first so a revoked account cannot reuse an old cached ticket.
    await repository.get('feedbackConcerns/${concern.id}');
    final rows = await repository.request(
      'POST',
      '/feedbackConcerns/${concern.id}:runQuery',
      {
        'structuredQuery': {
          'from': [
            {'collectionId': 'responses'},
          ],
        },
      },
    ) as List;
    final result = [
      for (final row in rows)
        if (row['document'] != null)
          repository.data(Map<String, dynamic>.from(row['document'] as Map)),
    ];
    result.sort(
      (a, b) => (a['createdAt'] as String).compareTo(b['createdAt'] as String),
    );
    return result;
  }

  @override
  Future<void> update(
    FeedbackConcern concern, {
    String? status,
    String? response,
  }) async {
    final a = await repository.account();
    if (!_staff(a)) {
      throw const BackendException('Staff authorization is required.', 403);
    }
    final text = response?.trim();
    if (text != null &&
        (text.isEmpty ||
            text.length > 2000 ||
            ['Resolved', 'Closed'].contains(concern.status))) {
      throw const BackendException(
        'Responses require an open concern and 1–2000 characters.',
      );
    }
    final next =
        status ??
        (concern.status == 'Submitted' && text != null
            ? 'Under Review'
            : concern.status);
    if ((next != concern.status && !concernTransition(concern.status, next)) ||
        (text == null && next == concern.status)) {
      throw const BackendException('This status change is not permitted.');
    }
    if (concern.version == null) {
      throw const BackendException('Refresh the concern before updating.');
    }
    final revision = (concern.values['revision'] as int) + 1;
    final responseId = 'R-$revision';
    final value = <String, dynamic>{
      'status': next,
      'revision': revision,
      'updatedBy': repository.uid(),
      'lastResponseId': text != null
          ? responseId
          : concern.values['lastResponseId'],
      'responseCount':
          (concern.values['responseCount'] as int) + (text != null ? 1 : 0),
    };
    final stamps = [
      'updatedAt',
      if (next == 'Resolved' && next != concern.status) 'resolvedAt',
      if (next == 'Closed' && next != concern.status) 'closedAt',
    ];
    final id = 'concern_${concern.id}_$revision';
    final role = concern.values['submittedByRole'],
        pid = concern.values['patientId'];
    final rid = role == 'patient' ? pid : concern.values['relativeId'];
    final patientRecord = await repository.get('patients/$pid');
    final canNotify =
        patientRecord != null &&
        repository.data(patientRecord)['recordStatus'] != 'archived';
    final notification = <String, dynamic>{
      'id': id,
      'eventId': id,
      'patientId': pid,
      'recipientId': rid,
      'recipientType': role,
      'recipientName': '',
      'recipientKey': '$role:$rid:$pid',
      'type': 'concernUpdate',
      'title': 'Feedback & Concerns',
      'message': text != null
          ? 'Staff responded to your concern. Open Feedback & Concerns to view it.'
          : 'Your concern is now $next.',
      'trigger': 'staff',
      'sessionId': '',
      'attempts': [],
      'readAt': null,
      'staffRead': false,
    };
    await repository.request('POST', ':commit', {
      'writes': [
        _write('feedbackConcerns/${concern.id}', value, stamps, {
          'updateTime': concern.version,
        }, patch: true),
        if (text != null)
          _write(
            'feedbackConcerns/${concern.id}/responses/$responseId',
            {
              'responseId': responseId,
              'responderUid': repository.uid(),
              'responderRole': a['role'],
              'message': text,
            },
            ['createdAt'],
            {'exists': false},
          ),
        if (canNotify)
          _write(
            'notifications/$id',
            notification,
            ['createdAt'],
            {'exists': false},
          ),
      ],
    });
  }
}

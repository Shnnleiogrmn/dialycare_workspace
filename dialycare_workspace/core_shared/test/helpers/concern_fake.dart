import 'package:core_shared/core_shared.dart';

class ConcernFake extends ConcernService {
  ConcernFake({this.role = 'patient'});
  final String role;
  final records = <FeedbackConcern>[];
  final replies = <String, List<Map<String, dynamic>>>{};
  bool denied = false;
  @override
  Future<List<FeedbackConcern>> list() async {
    if (denied) {
      throw const BackendException('Access is no longer authorized.', 403);
    }
    return List.of(records);
  }

  @override
  Future<void> submit(
    String id,
    String type,
    String subject,
    String message,
    String area,
  ) async {
    validateConcern(type, subject, message, area);
    records.add(
      FeedbackConcern(
        {
          'concernId': id,
          'concernType': type,
          'subject': subject.trim(),
          'message': message.trim(),
          'relatedArea': area,
          'status': 'Submitted',
          'submittedByRole': role,
          'createdAt': '2026-10-24T01:00:00Z',
          'revision': 0,
          'responseCount': 0,
          'lastResponseId': '',
        },
        version: 'fixture-version',
        submitter: 'Synthetic Owner',
        patient: 'Synthetic Patient • DC-000001',
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> responses(FeedbackConcern concern) async {
    if (denied) {
      throw const BackendException('Access is no longer authorized.', 403);
    }
    return List.of(replies[concern.id] ?? []);
  }

  @override
  Future<void> update(
    FeedbackConcern concern, {
    String? status,
    String? response,
  }) async {
    final i = records.indexWhere((c) => c.id == concern.id);
    final next =
        status ??
        (concern.status == 'Submitted' ? 'Under Review' : concern.status);
    if (next != concern.status && !concernTransition(concern.status, next)) {
      throw const BackendException('Invalid transition');
    }
    if (response != null) {
      if (response.trim().isEmpty) {
        throw const BackendException('Enter a response.');
      }
      replies.putIfAbsent(concern.id, () => []).add({
        'message': response,
        'responderRole': 'staff',
        'createdAt': '2026-10-24T02:00:00Z',
      });
    }
    records[i] = FeedbackConcern(
      {...concern.values, 'status': next},
      version: 'next-version',
      submitter: concern.submitter,
      patient: concern.patient,
    );
  }
}

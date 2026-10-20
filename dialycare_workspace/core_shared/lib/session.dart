import 'schedule_group.dart';

enum SessionStatus {
  pending('Pending'),
  inProgress('In Progress'),
  paused('Paused'),
  endedEarly('Ended Early'),
  completed('Completed'),
  readyForPickUp('Ready for Pick Up'),
  missed('Missed'),
  waiting('Waiting'),
  cancelled('Cancelled');

  const SessionStatus(this.label);
  final String label;
  static const editable = [
    pending,
    inProgress,
    paused,
    completed,
    readyForPickUp,
    missed,
    endedEarly,
    cancelled,
  ];
  static SessionStatus fromStorage(String value) {
    // Keep existing JSON labels compatible; migrate the incorrect legacy wording.
    if (value == 'Missing') return missed;
    return values.firstWhere(
      (status) => status.label == value || status.name == value,
      orElse: () => throw FormatException('Unknown session status: $value'),
    );
  }
}

bool sessionTransitionAllowed(SessionStatus from, SessionStatus to) =>
    from == to ||
    switch (from) {
      SessionStatus.pending => [
        SessionStatus.inProgress,
        SessionStatus.missed,
        SessionStatus.cancelled,
      ].contains(to),
      SessionStatus.inProgress => [
        SessionStatus.paused,
        SessionStatus.completed,
        SessionStatus.endedEarly,
      ].contains(to),
      SessionStatus.paused => [
        SessionStatus.inProgress,
        SessionStatus.endedEarly,
      ].contains(to),
      SessionStatus.waiting => [
        SessionStatus.inProgress,
        SessionStatus.completed,
        SessionStatus.endedEarly,
      ].contains(to),
      SessionStatus.completed => to == SessionStatus.readyForPickUp,
      SessionStatus.missed => to == SessionStatus.pending,
      _ => false,
    };

const pauseReasonCodes = [
  'equipment',
  'patientCondition',
  'assessment',
  'access',
  'temporary',
  'other',
];
const endReasonCodes = [
  'equipment',
  'patientCondition',
  'clinicalDecision',
  'patientRequest',
  'transfer',
  'other',
];
String sessionReasonLabel(String code) => switch (code) {
  'equipment' => 'Machine/Equipment Issue',
  'patientCondition' => 'Patient Condition',
  'assessment' => 'Clinical Assessment',
  'access' => 'Access Issue',
  'temporary' => 'Temporary Interruption',
  'clinicalDecision' => 'Clinical Decision',
  'patientRequest' => 'Patient Request',
  'transfer' => 'Transfer/Reschedule',
  _ => 'Other',
};

class PauseInterval {
  const PauseInterval({required this.pausedAt, this.resumedAt});
  final DateTime pausedAt;
  final DateTime? resumedAt;
  Map<String, dynamic> toJson() => {
    'pausedAt': pausedAt.toUtc().toIso8601String(),
    if (resumedAt != null) 'resumedAt': resumedAt!.toUtc().toIso8601String(),
  };
  factory PauseInterval.fromJson(Map<String, dynamic> j) => PauseInterval(
    pausedAt: DateTime.parse(j['pausedAt'] as String).toLocal(),
    resumedAt: DateTime.tryParse(j['resumedAt'] as String? ?? '')?.toLocal(),
  );
}

class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.patientId,
    required this.start,
    required this.room,
    required this.batch,
    required this.status,
    this.progress = 0,
    this.expectedEnd,
    this.revision = 0,
    this.plannedDurationMinutes,
    this.actualStartedAt,
    this.completedAt,
    this.scheduleGroup,
    this.endedAt,
    this.pauseSequence = 0,
    this.pauseIntervals = const {},
  });
  final String id, patientId, room, batch;
  final SessionStatus status;
  final DateTime start;
  final DateTime? expectedEnd;
  final int revision;
  final double progress;
  final int? plannedDurationMinutes;
  final DateTime? actualStartedAt, completedAt;
  final DateTime? endedAt;
  final int pauseSequence;
  final Map<String, PauseInterval> pauseIntervals;
  DateTime? get pausedAt => status == SessionStatus.paused
      ? pauseIntervals['p$pauseSequence']?.pausedAt
      : null;
  DateTime? get stoppedAt => completedAt ?? endedAt;
  final ScheduleGroup? scheduleGroup;
  Duration? elapsedAt(DateTime now) {
    final actual = actualStartedAt;
    if (actual == null) return null;
    final span = wallClockAt(now)! - totalPausedAt(now);
    return span.isNegative ? Duration.zero : span;
  }

  Duration? wallClockAt(DateTime now) => actualStartedAt == null
      ? null
      : ((stoppedAt ?? now).isBefore(actualStartedAt!)
            ? Duration.zero
            : (stoppedAt ?? now).difference(actualStartedAt!));
  Duration totalPausedAt(DateTime now) {
    final end = stoppedAt ?? now;
    var total = Duration.zero;
    for (final interval in pauseIntervals.values) {
      final until =
          interval.resumedAt == null || interval.resumedAt!.isAfter(end)
          ? end
          : interval.resumedAt!;
      if (until.isAfter(interval.pausedAt)) {
        total += until.difference(interval.pausedAt);
      }
    }
    return total;
  }

  DateTime? estimatedEndAt(DateTime now) =>
      actualStartedAt == null ||
          plannedDurationMinutes == null ||
          stoppedAt != null ||
          status == SessionStatus.paused
      ? null
      : actualStartedAt!.add(
          Duration(minutes: plannedDurationMinutes!) + totalPausedAt(now),
        );

  double? progressAt(DateTime now) {
    final elapsed = elapsedAt(now);
    final planned = plannedDurationMinutes;
    if (elapsed == null || planned == null || planned <= 0) return null;
    return (elapsed.inMilliseconds / Duration(minutes: planned).inMilliseconds)
        .clamp(0.0, 1.0);
  }

  DateTime? get estimatedEnd => estimatedEndAt(DateTime.now());
  bool get ongoing =>
      status == SessionStatus.inProgress ||
      status == SessionStatus.waiting ||
      status == SessionStatus.paused;
  bool get upcoming => status == SessionStatus.pending;
  bool get completed =>
      status == SessionStatus.completed ||
      status == SessionStatus.readyForPickUp;
  bool get finished =>
      completed ||
      status == SessionStatus.missed ||
      status == SessionStatus.endedEarly ||
      status == SessionStatus.cancelled;
  Map<String, dynamic> toJson() => {
    'id': id,
    'patientId': patientId,
    'start': start.toUtc().toIso8601String(),
    'room': room,
    'batch': batch,
    'status': status.label,
    'progress': progress,
    'revision': revision,
    'expectedEnd': expectedEnd?.toUtc().toIso8601String(),
    if (plannedDurationMinutes != null)
      'plannedDurationMinutes': plannedDurationMinutes,
    if (actualStartedAt != null)
      'actualStartedAt': actualStartedAt!.toUtc().toIso8601String(),
    if (completedAt != null)
      'completedAt': completedAt!.toUtc().toIso8601String(),
    if (scheduleGroup != null) 'scheduleGroup': scheduleGroup!.code,
    if (endedAt != null) 'endedAt': endedAt!.toUtc().toIso8601String(),
    if (pauseSequence > 0) 'pauseSequence': pauseSequence,
    if (pauseIntervals.isNotEmpty)
      'pauseIntervals': pauseIntervals.map((k, v) => MapEntry(k, v.toJson())),
  };
  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
    id: j['id'] as String,
    patientId: j['patientId'] as String,
    start: DateTime.parse(j['start'] as String).toLocal(),
    room: j['room'] as String,
    batch: j['batch'] as String,
    status: SessionStatus.fromStorage(j['status'] as String),
    progress: (j['progress'] as num?)?.toDouble() ?? 0,
    revision: j['revision'] as int? ?? 0,
    expectedEnd: DateTime.tryParse(j['expectedEnd'] as String? ?? '')
        ?.toLocal(),
    plannedDurationMinutes: (j['plannedDurationMinutes'] as num?)?.toInt(),
    actualStartedAt: DateTime.tryParse(j['actualStartedAt'] as String? ?? '')
        ?.toLocal(),
    completedAt: DateTime.tryParse(j['completedAt'] as String? ?? '')
        ?.toLocal(),
    scheduleGroup: ScheduleGroup.parse(j['scheduleGroup']),
    endedAt: DateTime.tryParse(j['endedAt'] as String? ?? '')?.toLocal(),
    pauseSequence: j['pauseSequence'] as int? ?? 0,
    pauseIntervals: ((j['pauseIntervals'] as Map?) ?? {}).map(
      (k, v) => MapEntry(
        k.toString(),
        PauseInterval.fromJson(Map<String, dynamic>.from(v as Map)),
      ),
    ),
  );
}

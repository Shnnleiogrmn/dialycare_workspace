import 'package:flutter/material.dart';

import 'session.dart';

Color sessionStatusBackground(SessionStatus value) => switch (value) {
  SessionStatus.pending || SessionStatus.paused => const Color(0xFFFFF1CC),
  SessionStatus.inProgress => const Color(0xFFDCEEFF),
  SessionStatus.completed => const Color(0xFFDDF3EE),
  SessionStatus.readyForPickUp => const Color(0xFFE4F5CE),
  SessionStatus.missed || SessionStatus.endedEarly => const Color(0xFFFBE1E4),
  SessionStatus.waiting || SessionStatus.cancelled => const Color(0xFFE9EEF3),
};
Color sessionStatusForeground(SessionStatus value) => switch (value) {
  SessionStatus.pending || SessionStatus.paused => const Color(0xFF765300),
  SessionStatus.inProgress => const Color(0xFF164B78),
  SessionStatus.completed => const Color(0xFF17664F),
  SessionStatus.readyForPickUp => const Color(0xFF355A1A),
  SessionStatus.missed || SessionStatus.endedEarly => const Color(0xFF922C3E),
  SessionStatus.waiting || SessionStatus.cancelled => const Color(0xFF42566A),
};
SessionRecord? nextDialysisSession(
  Iterable<SessionRecord> sessions,
  DateTime now,
) {
  final upcoming =
      sessions.where((s) => s.upcoming && !s.start.isBefore(now)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  return upcoming.firstOrNull;
}

SessionRecord? currentDialysisSession(
  Iterable<SessionRecord> sessions,
  DateTime now,
) {
  final active =
      sessions
          .where(
            (s) =>
                (s.status == SessionStatus.inProgress ||
                    s.status == SessionStatus.paused) &&
                s.actualStartedAt != null &&
                s.completedAt == null &&
                !s.actualStartedAt!.isAfter(now),
          )
          .toList()
        ..sort((a, b) => b.actualStartedAt!.compareTo(a.actualStartedAt!));
  if (active.isNotEmpty) return active.first;
  final today = sessions.where((s) {
    final d = s.start.toLocal();
    return d.year == now.year &&
        d.month == now.month &&
        d.day == now.day &&
        (!d.isAfter(now) || s.ongoing || s.completed);
  }).toList()..sort((a, b) => b.start.compareTo(a.start));
  return today.where((s) => s.ongoing).firstOrNull ?? today.firstOrNull;
}

String notificationCategory(String type) => switch (type) {
  'scheduleReminder' => 'Reminder',
  'sessionStarted' ||
  'sessionCompleted' ||
  'sessionPaused' ||
  'sessionResumed' ||
  'sessionEndedEarly' ||
  'endingSoon' ||
  'pickup' => 'Session',
  'scheduleCreated' ||
  'scheduleUpdated' ||
  'scheduleRescheduled' ||
  'scheduleCancelled' => 'Schedule',
  _ => 'Update',
};

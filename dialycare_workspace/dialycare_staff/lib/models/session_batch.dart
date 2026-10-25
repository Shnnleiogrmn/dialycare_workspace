import 'session.dart';

int compareBatchNames(String a, String b) {
  final matchA = RegExp(
    r'^batch\s+([a-z]+|\d+)$',
    caseSensitive: false,
  ).firstMatch(a.trim());
  final matchB = RegExp(
    r'^batch\s+([a-z]+|\d+)$',
    caseSensitive: false,
  ).firstMatch(b.trim());
  if (matchA != null && matchB != null) {
    final x = matchA[1]!.toUpperCase(), y = matchB[1]!.toUpperCase();
    final n = int.tryParse(x), m = int.tryParse(y);
    if (n != null && m != null) {
      final result = n.compareTo(m);
      if (result != 0) return result;
    }
    if (n == null && m == null) {
      final length = x.length.compareTo(y.length);
      if (length != 0) return length;
      final text = x.compareTo(y);
      if (text != 0) return text;
    }
  }
  final text = a.toLowerCase().compareTo(b.toLowerCase());
  return text != 0 ? text : a.compareTo(b);
}

class SessionBatch {
  SessionBatch(this.name, Iterable<SessionRecord> input)
    : sessions = List.unmodifiable(
        input.toList()..sort((a, b) {
          final time = a.start.compareTo(b.start);
          if (time != 0) return time;
          final patient = a.patientId.compareTo(b.patientId);
          return patient != 0 ? patient : a.id.compareTo(b.id);
        }),
      );
  final String name;
  final List<SessionRecord> sessions;
  int get patientCount => sessions.map((s) => s.patientId).toSet().length;
}

List<SessionBatch> groupSessionsByBatch(Iterable<SessionRecord> sessions) {
  final batches = <String, List<SessionRecord>>{};
  for (final session in sessions) {
    (batches[session.batch] ??= []).add(session);
  }
  final names = batches.keys.toList()..sort(compareBatchNames);
  return [for (final name in names) SessionBatch(name, batches[name]!)];
}

/// Only pending appointments on the nearest local calendar day after today.
List<SessionRecord> nearestUpcomingSessions(
  Iterable<SessionRecord> input,
  DateTime now, {
  bool Function(SessionRecord)? eligible,
}) {
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  final candidates =
      input.where((s) {
        final start = s.start.toLocal();
        final date = DateTime(start.year, start.month, start.day);
        return s.upcoming && date.isAfter(today) && (eligible?.call(s) ?? true);
      }).toList()..sort((a, b) {
        final time = a.start.compareTo(b.start);
        if (time != 0) return time;
        final batch = compareBatchNames(a.batch, b.batch);
        return batch != 0 ? batch : a.id.compareTo(b.id);
      });
  if (candidates.isEmpty) return candidates;
  final first = candidates.first.start.toLocal();
  return candidates.where((s) {
    final d = s.start.toLocal();
    return d.year == first.year && d.month == first.month && d.day == first.day;
  }).toList();
}

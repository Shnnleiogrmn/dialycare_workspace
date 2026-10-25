import 'package:flutter/material.dart';

import 'firestore_repository.dart';
import 'feedback_concerns.dart';
import 'session.dart';
import 'compact_date_range_picker.dart';

String historyTime(dynamic value) {
  final d = value is DateTime
      ? value.toLocal()
      : DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (d == null) return 'Not recorded';
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class HistoryItem {
  const HistoryItem({
    required this.category,
    required this.title,
    required this.patient,
    required this.timestamp,
    required this.details,
    this.status = '',
  });
  final String category, title, patient, timestamp, details, status;
}

abstract class HistoryService {
  Future<List<HistoryItem>> list();
}

class CallbackHistoryService implements HistoryService {
  CallbackHistoryService(this.read);
  final Future<List<HistoryItem>> Function() read;
  @override
  Future<List<HistoryItem>> list() => read();
}

List<HistoryItem> sessionHistoryItems(
  Iterable<SessionRecord> sessions,
  String Function(String) patient,
) {
  return [
    for (final s in sessions.where((s) => s.finished))
      HistoryItem(
        category: 'Sessions',
        title: s.status.label,
        patient: patient(s.patientId),
        timestamp: (s.stoppedAt ?? s.start).toUtc().toIso8601String(),
        status: s.status.label,
        details:
            'Batch: ${s.batch}\nScheduled: ${historyTime(s.start)}\nActual start: ${historyTime(s.actualStartedAt)}\nEnd: ${historyTime(s.stoppedAt)}\nPlanned duration: ${s.plannedDurationMinutes == null ? 'Not recorded' : '${s.plannedDurationMinutes} minutes'}\nActive duration: ${s.actualStartedAt == null || s.stoppedAt == null ? 'Not recorded' : '${s.elapsedAt(s.stoppedAt!)!.inMinutes} minutes'}'
            '${s.pauseIntervals.isEmpty ? '' : '\nPauses: ${s.pauseIntervals.length}\n${s.pauseIntervals.values.map((p) => 'Paused ${historyTime(p.pausedAt)}; resumed ${historyTime(p.resumedAt)}').join('\n')}'}',
      ),
  ];
}

class FirestoreHistoryService implements HistoryService {
  FirestoreHistoryService(this.repository);
  final FirestoreRepository repository;
  @override
  Future<List<HistoryItem>> list() async {
    final owner = await repository.account();
    final staff = ['staff', 'admin'].contains(owner['role']);
    final labels = <String, String>{};
    List<SessionRecord> sessions;
    List<Map<String, dynamic>> notifications = [];
    if (staff) {
      final records = await Future.wait([
        repository.query('patients'),
        repository.query('sessions'),
        repository.query('notifications'),
      ]);
      for (final d in records[0]) {
        final p = repository.data(d);
        labels[p['id'] as String? ?? (d['name'] as String).split('/').last] =
            '${p['name']} • ${p['publicId'] ?? 'Not assigned'}';
      }
      sessions = records[1]
          .map((d) => SessionRecord.fromJson(repository.data(d)))
          .toList();
      notifications = records[2].map(repository.data).toList();
    } else {
      final mobile = await repository.loadMobile(owner['role'] as String);
      final p = mobile['profile'] as Map;
      labels[owner['patientId'] as String] =
          '${p['patientName']} • ${p['patientId']}';
      sessions = (mobile['sessions'] as List)
          .map(
            (s) => SessionRecord.fromJson(Map<String, dynamic>.from(s as Map)),
          )
          .toList();
    }
    String label(String id) => labels[id] ?? 'Historical Patient';
    final result = sessionHistoryItems(sessions, label);
    final changes = await repository.query(
      'scheduleHistory',
      field: staff ? null : 'patientId',
      equals: staff ? null : owner['patientId'],
    );
    String schedule(dynamic d) => d == null
        ? 'Not recorded'
        : '${historyTime(d['start'])} • ${d['batch']} • ${d['room']} • ${d['plannedDurationMinutes'] ?? 'Unrecorded'} minutes';
    for (final d in changes) {
      final e = repository.data(d);
      result.add(
        HistoryItem(
          category: 'Schedule Changes',
          title: e['before'] == null ? 'Schedule created' : 'Schedule updated',
          patient: label(e['patientId'] as String),
          timestamp: e['createdAt'] as String,
          details:
              'Previous: ${schedule(e['before'])}\nNew: ${schedule(e['after'])}${staff ? '\nRecorded by: Authorized Staff' : ''}',
        ),
      );
    }
    final concerns = await FirestoreConcernService(repository).list();
    for (final c in concerns.where(
      (c) => ['Resolved', 'Closed'].contains(c.status),
    )) {
      result.add(
        HistoryItem(
          category: 'Feedback & Concerns',
          title: c.subject,
          patient: staff ? c.patient : label(owner['patientId'] as String),
          timestamp:
              (c.values['closedAt'] ??
                      c.values['resolvedAt'] ??
                      c.values['updatedAt'])
                  as String,
          status: c.status,
          details:
              '${c.id}\n${c.type}\nSubmitted: ${historyTime(c.values['createdAt'])}\nResolved: ${historyTime(c.values['resolvedAt'])}\nClosed: ${historyTime(c.values['closedAt'])}\nOpen Feedback & Concerns to view the original submission and Staff responses.',
        ),
      );
    }
    for (final n in notifications) {
      result.add(
        HistoryItem(
          category: 'Communications',
          title: n['title'] as String? ?? 'In-app notification',
          patient: label(n['patientId'] as String),
          timestamp: n['createdAt'] as String,
          details:
              'Recipient role: ${n['recipientType']}\nType: ${n['type']}\nRecipient read: ${n['readAt'] == null ? 'Not recorded' : historyTime(n['readAt'])}\nStaff read: ${n['staffRead'] == true ? 'Read' : 'Unread'}',
        ),
      );
    }
    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }
}

List<HistoryItem> visibleHistory(
  Iterable<HistoryItem> source, {
  String category = 'All history',
  String search = '',
  DateTimeRange? dates,
}) {
  final result = source.where((e) {
    final d = DateTime.tryParse(e.timestamp)?.toLocal();
    return (category == 'All history' || e.category == category) &&
        '${e.title} ${e.patient} ${e.status}'.toLowerCase().contains(
          search.toLowerCase(),
        ) &&
        (dates == null ||
            d != null &&
                !d.isBefore(dates.start) &&
                d.isBefore(
                  DateTime(dates.end.year, dates.end.month, dates.end.day + 1),
                ));
  }).toList();
  result.sort(
    (a, b) =>
        DateTime.parse(b.timestamp).compareTo(DateTime.parse(a.timestamp)),
  );
  return result;
}

class ActivityHistoryPage extends StatefulWidget {
  const ActivityHistoryPage({
    super.key,
    required this.service,
    this.staff = false,
    this.onBack,
  });
  final HistoryService service;
  final bool staff;
  final VoidCallback? onBack;
  @override
  State<ActivityHistoryPage> createState() => _ActivityHistoryPageState();
}

class _ActivityHistoryPageState extends State<ActivityHistoryPage> {
  List<HistoryItem> items = [];
  String category = 'All history', search = '';
  DateTimeRange? dates;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final values = await widget.service.list();
      if (mounted) setState(() => items = values);
    } catch (_) {
      if (mounted) {
        setState(() {
          items = [];
          error = 'History could not be loaded. Please try again or contact your center.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  static const ink = Color(0xff0b3764),
      line = Color(0xffdce5ed),
      wash = Color(0xfff0f6fa);

  IconData categoryIcon(String category) => switch (category) {
    'Sessions' => Icons.monitor_heart_outlined,
    'Schedule Changes' => Icons.calendar_month_outlined,
    'Feedback & Concerns' => Icons.feedback_outlined,
    _ => Icons.notifications_outlined,
  };

  String recordDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return 'Time not recorded';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year} • ${TimeOfDay.fromDateTime(date).format(context)}';
  }

  Future<void> chooseDates() async {
    final next = await showCompactDateRangePicker(
      context: context,
      initialDateRange: dates,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (mounted && next != null) setState(() => dates = next);
  }

  void details(HistoryItem item) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(item.title),
      content: SingleChildScrollView(
        child: Text(
          '${item.patient}\n${recordDate(item.timestamp)}\n\n${item.details}',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Widget record(HistoryItem item) => Card(
    elevation: 0,
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: line),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => details(item),
      hoverColor: wash,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: wash,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(categoryIcon(item.category), color: ink, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        item.category == 'Sessions' && item.title == item.status
                            ? 'Dialysis session'
                            : item.title,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (item.status.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: wash,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: line),
                          ),
                          child: Text(
                            item.status,
                            style: const TextStyle(
                              color: ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.patient,
                    style: const TextStyle(color: ink, fontSize: 14),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${item.category} • ${recordDate(item.timestamp)}',
                    style: const TextStyle(
                      color: Color(0xff536678),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Color(0xff64798a), size: 20),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final filtered = visibleHistory(
      items,
      category: category,
      search: search,
      dates: dates,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (widget.onBack != null) ...[
                    TextButton.icon(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back, size: 20),
                      label: const Text('Back'),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      'History',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: ink, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: busy ? null : load,
                    tooltip: 'Refresh history',
                    icon: const Icon(Icons.refresh, color: ink),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.staff
                    ? 'Review recorded patient, session, schedule, and communication activity.'
                    : 'View your recorded activity.',
                style: const TextStyle(color: Color(0xff536678)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: wide
                              ? constraints.maxWidth - 420
                              : constraints.maxWidth,
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Search history',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) =>
                                setState(() => search = value),
                          ),
                        ),
                        SizedBox(
                          width: wide ? 220 : constraints.maxWidth,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: category,
                                isDense: true,
                                isExpanded: true,
                                items: [
                                  for (final value in [
                                    'All history',
                                    'Sessions',
                                    'Schedule Changes',
                                    'Feedback & Concerns',
                                    if (widget.staff) 'Communications',
                                  ])
                                    DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                        value,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => category = value);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: chooseDates,
                          icon: const Icon(
                            Icons.calendar_month_outlined,
                            size: 20,
                          ),
                          label: Text(
                            dates == null
                                ? 'Date'
                                : '${historyRangeDate(dates!.start)} – ${historyRangeDate(dates!.end)}',
                          ),
                        ),
                        if (dates != null)
                          TextButton(
                            onPressed: () => setState(() => dates = null),
                            child: const Text('Clear dates'),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 15, color: Color(0xff64798a)),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Schedule-change history begins with the updated application; earlier edits are not reconstructed.',
                      style: TextStyle(fontSize: 12, color: Color(0xff64798a)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(error!),
                ),
              if (!busy && error == null && filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No historical records match these filters.'),
                ),
              for (final item in filtered) record(item),
            ],
          ),
        ),
      ],
    );
  }
}

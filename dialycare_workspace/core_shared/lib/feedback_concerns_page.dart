import 'dart:async';

import 'package:flutter/material.dart';

import 'backend_client.dart';
import 'feedback_concerns.dart';

/// Embedded in the Staff shell and in Mobile's existing More navigation.
class FeedbackConcernsPage extends StatefulWidget {
  const FeedbackConcernsPage({
    super.key,
    required this.service,
    this.staff = false,
  });
  final ConcernService service;
  final bool staff;
  @override
  State<FeedbackConcernsPage> createState() => _FeedbackConcernsPageState();
}

class _FeedbackConcernsPageState extends State<FeedbackConcernsPage> {
  List<FeedbackConcern> rows = [];
  String status = 'All statuses', type = 'All types', search = '';
  DateTimeRange? dates;
  bool loading = false;
  String? error;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        load();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  String failure(Object e) => e is BackendException && e.statusCode != 403
      ? e.message
      : "We couldn't load Feedback & Concerns. Please try again or contact an administrator.";
  Future<void> load() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.service.list();
      if (mounted) setState(() => rows = result);
    } catch (e) {
      if (mounted) {
        setState(() {
          rows = [];
          error = failure(e);
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String stamp(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (d == null) return 'Not recorded';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget badge(String value) => Chip(
    label: Text(value),
    backgroundColor: switch (value) {
      'Submitted' => Colors.blue.shade50,
      'Under Review' => Colors.orange.shade50,
      'Resolved' => Colors.green.shade50,
      _ => Colors.grey.shade100,
    },
  );
  Widget dropdown(
    String value,
    List<String> values,
    ValueChanged<String> change,
  ) => DropdownButton<String>(
    value: value,
    isExpanded: true,
    items: [
      for (final v in values)
        DropdownMenuItem(
          value: v,
          child: Text(v, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (v) {
      if (v != null) change(v);
    },
  );

  Future<void> compose() async {
    final subject = TextEditingController(), message = TextEditingController();
    final key = GlobalKey<FormState>();
    final id = newConcernId();
    var category = concernTypes.first, area = 'Other', saving = false;
    String? problem;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, change) => AlertDialog(
          title: const Text('Submit New Concern'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Your authenticated account and authorized Patient relationship will be used automatically. Do not include passwords or Temporary PINs. For urgent care needs, contact your center directly.',
                    ),
                    const SizedBox(height: 12),
                    dropdown(
                      category,
                      concernTypes,
                      (v) => change(() => category = v),
                    ),
                    TextFormField(
                      controller: subject,
                      maxLength: 120,
                      decoration: const InputDecoration(labelText: 'Subject'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter a subject.'
                          : null,
                    ),
                    TextFormField(
                      controller: message,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        labelText: 'Message / Description',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter a message.'
                          : null,
                    ),
                    const Text('Related area'),
                    dropdown(area, concernAreas, (v) => change(() => area = v)),
                    if (problem != null)
                      Text(
                        problem!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!key.currentState!.validate()) return;
                      change(() {
                        saving = true;
                        problem = null;
                      });
                      try {
                        await widget.service.submit(
                          id,
                          category,
                          subject.text,
                          message.text,
                          area,
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (e) {
                        if (dialogContext.mounted) {
                          change(() {
                            saving = false;
                            problem = failure(e);
                          });
                        }
                      }
                    },
              child: Text(saving ? 'Submitting…' : 'Submit Concern'),
            ),
          ],
        ),
      ),
    );
    // Dialog routes animate out before their text fields are disposed.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    subject.dispose();
    message.dispose();
    if (mounted) await load();
  }

  Future<void> detail(FeedbackConcern initial) async {
    var current = initial;
    var replies = widget.service.responses(current);
    final response = TextEditingController();
    var saving = false;
    String? problem;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, change) => AlertDialog(
          title: const Text('Concern Details'),
          content: SizedBox(
            width: 620,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: replies,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text(failure(snapshot.error!));
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 70,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(current.id),
                      badge(current.status),
                      if (widget.staff) ...[
                        Text('Submitted by: ${current.submitter}'),
                        Text('Role: ${current.role}'),
                      ],
                      Text('Related Patient: ${current.patient}'),
                      Text(
                        '${current.type} • ${current.values['relatedArea']}',
                      ),
                      Text('Submitted: ${stamp(current.values['createdAt'])}'),
                      const SizedBox(height: 12),
                      Text(
                        current.subject,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(current.values['message'] as String),
                      const Divider(),
                      const Text('Staff Responses'),
                      if (snapshot.data!.isEmpty)
                        const Text('No Staff response yet.'),
                      for (final reply in snapshot.data!)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${reply['responderRole'] == 'admin' ? 'Center Admin' : 'Staff'} • ${stamp(reply['createdAt'])}',
                                ),
                                Text(reply['message'] as String),
                              ],
                            ),
                          ),
                        ),
                      if (current.values['resolvedAt'] != null)
                        Text(
                          'Resolved: ${stamp(current.values['resolvedAt'])}',
                        ),
                      if (current.values['closedAt'] != null)
                        Text('Closed: ${stamp(current.values['closedAt'])}'),
                      if (widget.staff &&
                          [
                            'Submitted',
                            'Under Review',
                          ].contains(current.status))
                        TextField(
                          controller: response,
                          minLines: 2,
                          maxLines: 5,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            labelText: 'Response to Patient/Relative',
                          ),
                        ),
                      if (problem != null)
                        Text(
                          problem!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: saving
                  ? null
                  : () {
                      change(() {
                        replies = widget.service.list().then((items) {
                          current = items.firstWhere((c) => c.id == current.id);
                          return widget.service.responses(current);
                        });
                        problem = null;
                      });
                    },
              child: const Text('Refresh'),
            ),
            if (widget.staff && current.status != 'Closed')
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final next =
                            concernStatuses[concernStatuses.indexOf(
                                  current.status,
                                ) +
                                1];
                        change(() {
                          saving = true;
                          problem = null;
                        });
                        try {
                          await widget.service.update(current, status: next);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            change(() {
                              saving = false;
                              problem =
                                  '${failure(e)} Refresh before retrying.';
                            });
                          }
                        }
                      },
                child: Text(switch (current.status) {
                  'Submitted' => 'Mark Under Review',
                  'Under Review' => 'Mark Resolved',
                  _ => 'Close Concern',
                }),
              ),
            if (widget.staff &&
                ['Submitted', 'Under Review'].contains(current.status))
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        change(() {
                          saving = true;
                          problem = null;
                        });
                        try {
                          await widget.service.update(
                            current,
                            response: response.text,
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            change(() {
                              saving = false;
                              problem =
                                  '${failure(e)} Refresh before retrying.';
                            });
                          }
                        }
                      },
                child: const Text('Send Response'),
              ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    response.dispose();
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = rows.where((c) {
      final d = DateTime.tryParse(c.values['createdAt'] as String)?.toLocal();
      return (status == 'All statuses' || c.status == status) &&
          (type == 'All types' || c.type == type) &&
          (dates == null ||
              d != null &&
                  !d.isBefore(dates!.start) &&
                  d.isBefore(dates!.end.add(const Duration(days: 1)))) &&
          '${c.id} ${c.subject} ${c.submitter} ${c.patient}'
              .toLowerCase()
              .contains(search.toLowerCase());
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Feedback & Concerns',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: loading ? null : load,
                tooltip: 'Refresh concerns',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              if (widget.staff)
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    for (final s in [
                      'Submitted',
                      'Under Review',
                      'Resolved',
                      'Total',
                    ])
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '$s: ${s == 'Total' ? rows.length : rows.where((c) => c.status == s).length}',
                          ),
                        ),
                      ),
                  ],
                )
              else ...[
                FilledButton.icon(
                  onPressed: loading ? null : compose,
                  icon: const Icon(Icons.add),
                  label: const Text('Submit New Concern'),
                ),
                const SizedBox(height: 16),
                const Text('My Concerns'),
              ],
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search concerns',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => search = v),
              ),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    child: dropdown(status, [
                      'All statuses',
                      ...concernStatuses,
                    ], (v) => setState(() => status = v)),
                  ),
                  SizedBox(
                    width: 230,
                    child: dropdown(type, [
                      'All types',
                      ...concernTypes,
                    ], (v) => setState(() => type = v)),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      dates == null ? 'Filter by date' : 'Date filter applied',
                    ),
                    onPressed: () async {
                      final value = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                        initialDateRange: dates,
                      );
                      if (mounted && value != null) {
                        setState(() => dates = value);
                      }
                    },
                  ),
                  if (dates != null)
                    TextButton(
                      onPressed: () => setState(() => dates = null),
                      child: const Text('Clear dates'),
                    ),
                ],
              ),
              if (loading) const LinearProgressIndicator(),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (!loading && error == null && filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No concerns found.'),
                ),
              for (final c in filtered)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [Text(c.id), badge(c.status)],
                        ),
                        Text(
                          c.subject,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('${c.type} • ${stamp(c.values['createdAt'])}'),
                        if (widget.staff)
                          Text(
                            '${c.submitter} • ${c.role}\nRelated Patient: ${c.patient}',
                          ),
                        TextButton(
                          onPressed: () => detail(c),
                          child: const Text('View'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

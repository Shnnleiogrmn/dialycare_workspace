import 'package:core_shared/core_shared.dart' show ScheduleGroup, PersonLabel;
import 'package:flutter/material.dart';

import '../../services/staff_store.dart';
import '../../theme/staff_theme.dart';
import '../../widgets/staff_components.dart';
import '../../widgets/pickers.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/patient_details.dart';
import '../../widgets/planned_duration_field.dart';

class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key, required this.store});
  final StaffStore store;
  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  int tab = 0;
  String batch = 'All Batches', query = '';
  DateTime day = DateUtils.dateOnly(DateTime.now());
  final Map<String, String> patientBatches = {};
  final Map<String, DateTime> patientTimes = {};
  final Map<String, int> patientDurations = {};
  final Set<String> saving = {};
  bool groupOnly = true;
  Future<void> _add(String id) async {
    final p = widget.store.patientFor(id);
    final time = patientTimes[id] ?? DateTime(day.year, day.month, day.day, 9);
    if (saving.contains(id)) return;
    setState(() => saving.add(id));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Schedule?'),
        content: Text(
          '${p.name} • ${p.displayId}\n${shortDate(time)} • ${sessionTime(time)}\n${patientBatches[id] ?? p.batch} • ${patientDurations[id] ?? 240} min',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      if (mounted) setState(() => saving.remove(id));
      return;
    }
    setState(() => saving.add(id));
    try {
      await widget.store.addSchedule(
        p,
        time,
        patientBatches[id] ?? p.batch,
        plannedDurationMinutes: patientDurations[id] ?? 240,
      );
      if (mounted) {
        showNotice(context, 'Schedule added for ${p.name}.');
        setState(() {
          day = DateUtils.dateOnly(time);
          tab = 0;
        });
      }
    } catch (error) {
      if (mounted) {
        showNotice(
          context,
          error is StateError
              ? error.message
              : 'Could not save the schedule. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving.remove(id));
      }
    }
  }

  void addToBatch(String name) {
    final config = widget.store.batchConfiguration(name),
        minute = config?['startMinute'] as int?;
    setState(() {
      batch = name;
      tab = 1;
      groupOnly = true;
      query = '';
      for (final p in widget.store.activePatients) {
        patientBatches[p.id] = name;
        patientTimes[p.id] = DateTime(
          day.year,
          day.month,
          day.day,
          minute == null ? 9 : minute ~/ 60,
          minute == null ? 0 : minute % 60,
        );
      }
    });
  }

  String minuteLabel(int n) =>
      sessionTime(DateTime(day.year, day.month, day.day, n ~/ 60, n % 60));
  String configTime(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  int? parseTime(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
    if (h == null ||
        m == null ||
        h < 0 ||
        h > 24 ||
        m < 0 ||
        m > 59 ||
        (h == 24 && m != 0)) {
      return null;
    }
    return h * 60 + m;
  }

  Future<void> configure() async {
    String? selected;
    final name = TextEditingController(),
        start = TextEditingController(),
        end = TextEditingController(),
        capacity = TextEditingController();
    bool active = true, busy = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Configure Batch'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Existing batch (or enter a new name)',
                    ),
                    items: [
                      for (final b in widget.store.batchConfigurations)
                        DropdownMenuItem(
                          value: b['id'] as String,
                          child: Text(b['name'] as String),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (id) => update(() {
                            selected = id;
                            final b = widget.store.batchConfigurations
                                .firstWhere((b) => b['id'] == id);
                            name.text = b['name'] as String;
                            start.text = configTime(b['startMinute'] as int);
                            end.text = configTime(b['endMinute'] as int);
                            capacity.text = b['capacity']?.toString() ?? '';
                            active = b['active'] == true;
                          }),
                  ),
                  TextField(
                    controller: name,
                    enabled: !busy,
                    maxLength: 40,
                    decoration: const InputDecoration(labelText: 'Batch name'),
                  ),
                  TextField(
                    controller: start,
                    enabled: !busy,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Start time (24-hour)',
                      helperText: 'Example: 08:00',
                    ),
                  ),
                  TextField(
                    controller: end,
                    enabled: !busy,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'End time (24-hour)',
                      helperText: 'Example: 12:00',
                    ),
                  ),
                  TextField(
                    controller: capacity,
                    enabled: !busy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Capacity (optional)',
                    ),
                  ),
                  SwitchListTile(
                    value: active,
                    title: const Text('Active'),
                    onChanged: busy ? null : (v) => update(() => active = v),
                  ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final a = parseTime(start.text),
                          b = parseTime(end.text),
                          c = int.tryParse(capacity.text);
                      if (name.text.trim().isEmpty ||
                          a == null ||
                          b == null ||
                          a < 0 ||
                          b > 1440 ||
                          a >= b ||
                          (capacity.text.isNotEmpty &&
                              (c == null || c < 1 || c > 1000))) {
                        update(
                          () => error = 'Enter a name, valid time range (HH:mm), and optional positive capacity.',
                        );
                        return;
                      }
                      update(() => busy = true);
                      try {
                        await widget.store.configureBatch({
                          'id':
                              selected ??
                              'B-${DateTime.now().microsecondsSinceEpoch}',
                          'name': name.text.trim(),
                          'startMinute': a,
                          'endMinute': b,
                          'capacity': c,
                          'active': active,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) setState(() {});
                      } catch (_) {
                        if (ctx.mounted) {
                          update(() {
                            busy = false;
                            error = 'Unable to save. Refresh and try again.';
                          });
                        }
                      }
                    },
              child: Text(busy ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    start.dispose();
    end.dispose();
    capacity.dispose();
  }

  Widget _schedule() {
    final rows =
        widget.store.sessions.where((s) => sameDay(s.start, day)).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final names = {
      ...widget.store.batchConfigurations
          .where((b) => b['active'] == true)
          .map((b) => b['name'] as String),
      ...rows.map((s) => s.batch),
    }.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Previous day',
                  onPressed: () => setState(
                    () => day = day.subtract(const Duration(days: 1)),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Builder(
                  builder: (anchor) => SelectorButton(
                    label: shortDate(day),
                    icon: Icons.calendar_month_outlined,
                    onPressed: () async {
                      final date = await chooseDate(anchor, day);
                      if (date != null && mounted) setState(() => day = date);
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Next day',
                  onPressed: () =>
                      setState(() => day = day.add(const Duration(days: 1))),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Chip(
              label: Text(
                ScheduleGroup.forDay(day)?.label ?? 'No regular group',
              ),
            ),
            SizedBox(
              width: 240,
              child: AppSearchField(
                hint: 'Search Patient name or ID',
                onChanged: (v) =>
                    setState(() => query = v.trim().toLowerCase()),
              ),
            ),
            FilledButton(
              onPressed: () => setState(() {
                tab = 1;
                groupOnly = true;
              }),
              child: const Text('+ Add Schedule'),
            ),
            if (widget.store.isCenterAdmin)
              TextButton(
                onPressed: configure,
                child: const Text('Configure Batches'),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (names.isEmpty)
          const AppPanel(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No batches scheduled for this date. Add a schedule or ask your Center Admin to configure time slots.',
              ),
            ),
          ),
        for (final name in names)
          Builder(
            builder: (context) {
              final config = widget.store.batchConfiguration(name);
              final all = rows.where((s) => s.batch == name).toList();
              final visible = all
                  .where(
                    (s) =>
                        '${widget.store.patientFor(s.patientId).name} ${widget.store.publicIdFor(s.patientId)}'
                            .toLowerCase()
                            .contains(query),
                  )
                  .toList();
              final count = all
                  .where(
                    (s) =>
                        s.status.label != 'Cancelled' &&
                        s.status.label != 'Missed',
                  )
                  .map((s) => s.patientId)
                  .toSet()
                  .length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: AppPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 20,
                          runSpacing: 12,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$name${config == null ? '' : ' • ${minuteLabel(config['startMinute'] as int)} – ${minuteLabel(config['endMinute'] as int)}'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  config?['capacity'] == null
                                      ? '$count Patients'
                                      : '$count / ${config!['capacity']} Patients',
                                ),
                              ],
                            ),
                            OutlinedButton(
                              onPressed: () => addToBatch(name),
                              child: const Text('Add Patients'),
                            ),
                          ],
                        ),
                      ),
                      DialyCareTable(
                        striped: true,
                        headerColor: StaffTheme.gray,
                        columns: const [
                          TableColumn('Patient', 30),
                          TableColumn('Room', 15),
                          TableColumn('Time', 15),
                          TableColumn('Status', 25),
                          TableColumn('Action', 15),
                        ],
                        rows: [
                          for (final s in visible)
                            [
                              PersonLabel(
                                name: widget.store.patientFor(s.patientId).name,
                                gender: widget.store
                                    .patientFor(s.patientId)
                                    .gender,
                                subtitle: widget.store.publicIdFor(s.patientId),
                              ),
                              Text(s.room),
                              Text(sessionTime(s.start)),
                              StatusChip(s.status),
                              ViewAction(
                                store: widget.store,
                                patient: widget.store.patientFor(s.patientId),
                                session: s,
                                title: 'Schedule Details',
                              ),
                            ],
                        ],
                        empty: 'No matching Patients in this batch.',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _addSchedule() {
    final rows = widget.store.activePatients
        .where(
          (p) =>
              !groupOnly ||
              ScheduleGroup.forDay(day) == null ||
              p.scheduleGroup == ScheduleGroup.forDay(day),
        )
        .where(
          (p) => [
            p.name,
            p.displayId,
            p.contact,
          ].any((v) => v.toLowerCase().contains(query)),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => tab = 0),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to schedules'),
          ),
        ),
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            title: Text(
              'Show ${ScheduleGroup.forDay(day)?.label ?? "all"} Patients for ${shortDate(day)}',
            ),
            subtitle: const Text(
              'Select Patients explicitly. No appointments are created automatically.',
            ),
            value: groupOnly,
            onChanged: (v) => setState(() => groupOnly = v),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: AppSearchField(
              hint: 'Search patient name or ID',
              onChanged: (v) => setState(() => query = v.trim().toLowerCase()),
            ),
          ),
        ),
        const SizedBox(height: 26),
        DialyCareTable(
          minWidth: 1150,
          rowHeight: 90,
          columns: const [
            TableColumn('Patient ID', 13),
            TableColumn('Name', 20),
            TableColumn('Contact', 20),
            TableColumn('Batch', 15),
            TableColumn('Date / Time', 22),
            TableColumn('Planned Duration', 20),
            TableColumn('Action', 11),
          ],
          rows: [
            for (final p in rows)
              [
                Text(p.displayId),
                PersonLabel(name: p.name, gender: p.gender),
                Text(p.contact),
                Builder(
                  builder: (anchor) => TextButton(
                    onPressed: () async {
                      final value = await chooseOption(
                        anchor,
                        title: 'Batch',
                        options: widget.store.batches
                            .where((b) => b != 'All Batches')
                            .toList(),
                        value: patientBatches[p.id] ?? p.batch,
                      );
                      if (value != null && mounted) {
                        setState(() => patientBatches[p.id] = value);
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: Text(patientBatches[p.id] ?? p.batch)),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 16),
                      ],
                    ),
                  ),
                ),
                Builder(
                  builder: (anchor) {
                    final time =
                        patientTimes[p.id] ??
                        DateTime(day.year, day.month, day.day, 9);
                    return TextButton(
                      onPressed: () async {
                        final date = await chooseDate(anchor, time, time: true);
                        if (date != null && mounted) {
                          setState(() => patientTimes[p.id] = date);
                        }
                      },
                      child: Text(
                        '${shortDate(time)}\n${sessionTime(time)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    );
                  },
                ),
                PlannedDurationField(
                  value: patientDurations[p.id] ?? 240,
                  onChanged: saving.contains(p.id)
                      ? null
                      : (v) => setState(() => patientDurations[p.id] = v),
                ),
                SizedBox(
                  width: 76,
                  height: 32,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: StaffTheme.blue,
                      foregroundColor: StaffTheme.navy,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: saving.contains(p.id) ? null : () => _add(p.id),
                    child: Text(saving.contains(p.id) ? 'Saving' : 'Add'),
                  ),
                ),
              ],
          ],
          empty: 'No patients found.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageHeader('Dialysis Schedule & Batch Management'),
      PageBody(
        padding: const EdgeInsets.all(28),
        children: [tab == 0 ? _schedule() : _addSchedule()],
      ),
    ],
  );
}

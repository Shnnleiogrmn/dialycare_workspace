import 'package:flutter/material.dart';
import 'package:core_shared/core_shared.dart'
    show SessionProgress, SessionStatus, PersonLabel;

import '../../models/session_batch.dart';
import '../../services/staff_store.dart';
import '../../theme/staff_theme.dart';
import '../../widgets/staff_components.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/patient_details.dart';
import '../../widgets/pickers.dart';
import '../notifications/reminder_composer.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key, required this.store, this.day});
  final StaffStore store;
  final DateTime? day;
  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  int tab = 0;
  late DateTime day;
  @override
  void initState() {
    super.initState();
    day = DateUtils.dateOnly(widget.day ?? DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final today = widget.store.sessions
        .where((s) => sameDay(s.start, day))
        .toList();
    final categories = [
      today.where((s) => s.ongoing).toList(),
      nearestUpcomingSessions(
        widget.store.sessions,
        widget.day ?? DateTime.now(),
        eligible: (s) => !widget.store.patientFor(s.patientId).archived,
      ),
      today.where((s) => s.finished).toList(),
    ];
    final batches = groupSessionsByBatch(categories[tab]);
    final pendingToday = groupSessionsByBatch(
      today.where(
        (s) => s.upcoming && !widget.store.patientFor(s.patientId).archived,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader('Sessions Management'),
        SectionTabs(
          labels: [
            'Ongoing (${categories[0].length})',
            'Upcoming (${categories[1].length})',
            'Completed (${categories[2].length})',
          ],
          index: tab,
          onChanged: (value) => setState(() => tab = value),
        ),
        PageBody(
          padding: const EdgeInsets.all(28),
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (tab == 1 && categories[1].isNotEmpty)
                  Text(
                    'Next scheduled date • ${shortDate(categories[1].first.start.toLocal())}',
                    key: const ValueKey('upcoming-date'),
                  ),
                if (tab != 1)
                  Builder(
                    builder: (anchor) => SelectorButton(
                      width: 240,
                      label:
                          '${sameDay(day, DateTime.now()) ? 'Today • ' : ''}${shortDate(day)}',
                      icon: Icons.calendar_month_outlined,
                      onPressed: () async {
                        final date = await chooseDate(anchor, day);
                        if (date != null && mounted) {
                          setState(() => day = DateUtils.dateOnly(date));
                        }
                      },
                    ),
                  ),
                if (tab != 1 && !sameDay(day, DateTime.now()))
                  TextButton(
                    onPressed: () => setState(
                      () => day = DateUtils.dateOnly(DateTime.now()),
                    ),
                    child: const Text('Today'),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (batches.isEmpty)
              AppPanel(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Text(
                    tab == 1
                        ? 'No upcoming sessions scheduled.'
                        : 'No ${tab == 0
                              ? 'ongoing'
                              : tab == 1
                              ? 'upcoming'
                              : 'finished'} sessions for this date.',
                  ),
                ),
              ),
            for (final batch in batches) ...[
              SessionBatchSection(
                batch: batch,
                store: widget.store,
                showProgress: tab == 0,
              ),
              const SizedBox(height: 20),
            ],
            if (tab == 0 && pendingToday.isNotEmpty) ...[
              const Text(
                'Scheduled for selected date',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              for (final batch in pendingToday) ...[
                SessionBatchSection(
                  batch: batch,
                  store: widget.store,
                  showProgress: false,
                ),
                const SizedBox(height: 20),
              ],
            ],
          ],
        ),
      ],
    );
  }
}

class SessionBatchSection extends StatelessWidget {
  const SessionBatchSection({
    super.key,
    required this.batch,
    required this.store,
    required this.showProgress,
  });
  final SessionBatch batch;
  final StaffStore store;
  final bool showProgress;
  @override
  Widget build(BuildContext context) => AppPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: ValueKey('batch-${batch.name}'),
          color: StaffTheme.blue.withValues(alpha: .35),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  batch.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: StaffTheme.navy,
                  ),
                ),
              ),
              Text(
                '${batch.patientCount} ${batch.patientCount == 1 ? 'Patient' : 'Patients'}',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
        DialyCareTable(
          minWidth: showProgress ? 960 : 900,
          striped: true,
          rowHeight: showProgress ? 106 : 64,
          headerColor: StaffTheme.gray,
          columns: [
            const TableColumn('Patient Name', 22),
            const TableColumn('Assign Room', 14),
            const TableColumn('Batch', 11),
            const TableColumn('Start Time', 13),
            if (showProgress) const TableColumn('Progress', 14),
            const TableColumn('Status', 23),
            const TableColumn('Action', 16),
          ],
          rows: [
            for (final s in batch.sessions)
              [
                PersonLabel(
                  name: store.patientFor(s.patientId).name,
                  gender: store.patientFor(s.patientId).gender,
                  subtitle: store.publicIdFor(s.patientId),
                ),
                Text(s.room),
                Text(s.batch),
                Text(sessionTime(s.start)),
                if (showProgress) SessionProgress(session: s, compact: true),
                StatusChip(s.status),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: TextButton(
                        key: ValueKey('manage-${s.id}'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(58, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        onPressed: store.signedIn
                            ? () => showSessionManagement(context, store, s)
                            : null,
                        child: const Text(
                          'Manage',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Flexible(
                      child: ViewAction(
                        store: store,
                        patient: store.patientFor(s.patientId),
                        session: s,
                        title: 'Session Details',
                      ),
                    ),
                  ],
                ),
              ],
          ],
        ),
        if (showProgress)
          for (final s in batch.sessions)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${store.patientFor(s.patientId).name} • ${store.publicIdFor(s.patientId)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    '${s.scheduleGroup?.label ?? 'Group not assigned'} • ${s.batch} • ${s.room}',
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: StatusChip(s.status),
                  ),
                  const SizedBox(height: 12),
                  SessionProgress(session: s),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      ViewAction(
                        store: store,
                        patient: store.patientFor(s.patientId),
                        session: s,
                        title: 'Session Details',
                      ),
                      if (s.status == SessionStatus.inProgress ||
                          s.status == SessionStatus.paused) ...[
                        OutlinedButton(
                          onPressed: store.signedIn
                              ? () => showSessionManagement(
                                  context,
                                  store,
                                  s,
                                  initialStatus:
                                      s.status == SessionStatus.paused
                                      ? SessionStatus.inProgress
                                      : SessionStatus.paused,
                                )
                              : null,
                          child: Text(
                            s.status == SessionStatus.paused
                                ? 'Resume'
                                : 'Pause',
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade800,
                          ),
                          onPressed: store.signedIn
                              ? () => showSessionManagement(
                                  context,
                                  store,
                                  s,
                                  initialStatus: SessionStatus.endedEarly,
                                )
                              : null,
                          child: const Text('End Early'),
                        ),
                      ],
                      if (s.status == SessionStatus.inProgress)
                        FilledButton(
                          onPressed: store.signedIn
                              ? () => showSessionManagement(
                                  context,
                                  store,
                                  s,
                                  initialStatus: SessionStatus.completed,
                                )
                              : null,
                          child: const Text('Complete Session'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}

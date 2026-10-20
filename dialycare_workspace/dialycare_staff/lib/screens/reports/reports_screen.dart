import '../../models/session.dart';

import 'package:flutter/material.dart';

import '../../services/staff_store.dart';
import '../../theme/staff_theme.dart';
import '../../widgets/staff_components.dart';
import '../../widgets/pickers.dart';
import '../../widgets/patient_details.dart';
import '../../widgets/status_chip.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.store});
  final StaffStore store;
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTimeRange range;
  String batch = 'All Batches';
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateUtils.dateOnly(now),
    );
  }

  @override
  Widget build(BuildContext context) {
    final end = DateTime(range.end.year, range.end.month, range.end.day + 1);
    final all = widget.store.sessions
        .where(
          (s) =>
              !s.start.isBefore(range.start) &&
              s.start.isBefore(end) &&
              (batch == 'All Batches' || s.batch == batch),
        )
        .toList();
    final rows =
        all
            .where((s) => s.completed || s.status == SessionStatus.missed)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader('Reports'),
        PageBody(
          children: [
            Wrap(
              spacing: 80,
              runSpacing: 16,
              children: [
                Builder(
                  builder: (anchor) => SelectorButton(
                    label:
                        '${shortDate(range.start)} - ${shortDate(range.end)}',
                    icon: Icons.calendar_month_outlined,
                    onPressed: () async {
                      final next = await chooseDateRange(anchor, range);
                      if (next != null && mounted) {
                        setState(() => range = next);
                      }
                    },
                  ),
                ),
                Builder(
                  builder: (anchor) => SelectorButton(
                    label: batch,
                    onPressed: () async {
                      final next = await chooseOption(
                        anchor,
                        title: 'Batch',
                        options: widget.store.batches,
                        value: batch,
                      );
                      if (next != null && mounted) {
                        setState(() => batch = next);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),
            SummaryGrid(
              children: [
                SummaryCard(
                  label: 'Total Sessions',
                  count: all.length,
                  people: false,
                ),
                SummaryCard(
                  label: 'Completed',
                  count: all.where((s) => s.completed).length,
                  people: false,
                  icon: Icons.groups,
                  color: StaffTheme.teal,
                ),
                SummaryCard(
                  label: 'Missed',
                  count: all
                      .where((s) => s.status == SessionStatus.missed)
                      .length,
                  people: false,
                  icon: Icons.person,
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 40),
            DialyCareTable(
              columns: const [
                TableColumn('Patient Name', 22),
                TableColumn('Assign Room', 15),
                TableColumn('Batch', 12),
                TableColumn('Session Start Time', 19),
                TableColumn('Session Status', 22),
                TableColumn('Action', 10),
              ],
              rows: [
                for (final s in rows)
                  [
                    Text(
                      widget.store.patientFor(s.patientId).name,
                      textAlign: TextAlign.center,
                    ),
                    Text(s.room),
                    Text(s.batch),
                    Text(sessionTime(s.start)),
                    StatusChip(s.status),
                    ViewAction(
                      store: widget.store,
                      patient: widget.store.patientFor(s.patientId),
                      session: s,
                      title: 'Report Details',
                    ),
                  ],
              ],
              empty: 'No completed or missed sessions match these filters.',
            ),
          ],
        ),
      ],
    );
  }
}

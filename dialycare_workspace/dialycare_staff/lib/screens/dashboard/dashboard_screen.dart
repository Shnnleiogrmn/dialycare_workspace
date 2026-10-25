import 'package:flutter/material.dart';
import 'package:core_shared/core_shared.dart' show PersonLabel;

import '../../services/staff_store.dart';
import '../../models/session.dart';
import '../../theme/staff_theme.dart';
import '../../widgets/staff_components.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/patient_details.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.store,
    required this.now,
    this.onNotifications,
  });
  final StaffStore store;
  final DateTime now;
  final VoidCallback? onNotifications;
  @override
  Widget build(BuildContext context) {
    final today =
        store.sessions
            .where(
              (s) =>
                  sameDay(s.start, now) &&
                  (!store.patientFor(s.patientId).archived || !s.upcoming),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final greeting = now.hour < 12
        ? 'Good Morning!'
        : now.hour < 18
        ? 'Good Afternoon!'
        : 'Good Evening!';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageBody(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
          children: [
            LayoutBuilder(
              builder: (context, constraints) => Column(
                key: const ValueKey('dashboard-header'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 24,
                      runSpacing: 10,
                      children: [
                        Text(
                          greeting,
                          style: TextStyle(
                            fontSize: constraints.maxWidth < 600 ? 24 : 27,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Open notifications',
                              onPressed: onNotifications,
                              icon: const Icon(
                                Icons.notifications_none_outlined,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                fullDate(now),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    "Here's what's happening today at the dialysis center.",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SummaryGrid(
              children: [
                SummaryCard(
                  label: 'Total Patients Today',
                  count: today.map((s) => s.patientId).toSet().length,
                ),
                SummaryCard(
                  label: 'Active Sessions',
                  count: today.where((s) => s.ongoing).length,
                ),
                SummaryCard(
                  label: 'Pending',
                  count: today.where((s) => s.upcoming).length,
                ),
                SummaryCard(
                  label: 'Completed',
                  count: today
                      .where((s) => s.status == SessionStatus.completed)
                      .length,
                ),
                SummaryCard(
                  label: 'Ready for Pick Up',
                  count: today
                      .where((s) => s.status == SessionStatus.readyForPickUp)
                      .length,
                ),
              ],
            ),
            const SizedBox(height: 28),
            AppPanel(
              shadow: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      "Today's Schedule",
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DialyCareTable(
                    columns: const [
                      TableColumn('Patient Name', 22),
                      TableColumn('Assign Room', 14),
                      TableColumn('Batch', 11),
                      TableColumn('Session Start Time', 18),
                      TableColumn('Session Status', 23),
                      TableColumn('Action', 10),
                    ],
                    rows: [
                      for (final s in today)
                        [
                          PersonLabel(
                            name: store.patientFor(s.patientId).name,
                            gender: store.patientFor(s.patientId).gender,
                            subtitle: store.publicIdFor(s.patientId),
                          ),
                          Text(s.room),
                          Text(s.batch),
                          Text(sessionTime(s.start)),
                          StatusChip(s.status),
                          ViewAction(
                            store: store,
                            patient: store.patientFor(s.patientId),
                            session: s,
                            title: 'Schedule Details',
                          ),
                        ],
                    ],
                    empty: 'No sessions are scheduled for today.',
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

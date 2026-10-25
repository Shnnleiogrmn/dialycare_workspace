import 'package:flutter/material.dart';

import '../../services/staff_store.dart';
import '../../models/session.dart';
import '../../models/notification_delivery.dart';
import '../../theme/staff_theme.dart';
import '../../widgets/staff_components.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.store});
  final StaffStore store;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int tab = 0;
  Future<void> _read([String? id]) async {
    try {
      if (id == null) {
        await widget.store.markAllRead();
      } else {
        await widget.store.markRead(id);
      }
      if (mounted && id == null) {
        showNotice(context, 'All notifications marked as read.');
      }
    } catch (_) {
      if (mounted) {
        showNotice(context, 'Could not save the read state.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const categories = ['All', 'Patients', 'Relatives', 'System'];
    final deliveries = {for (final d in widget.store.deliveryHistory) d.id: d};
    final items = [
      ...widget.store.notifications,
      for (final d in deliveries.values)
        StaffNotification(
          id: d.id,
          category: d.recipientType == RecipientType.patient
              ? 'Patients'
              : d.recipientType == RecipientType.staff
              ? 'System'
              : 'Relatives',
          title: d.title,
          message:
              '${d.recipientName}\nPatient ID: ${widget.store.publicIdFor(d.patientId)}\n${d.message}',
          time: d.createdAt,
          icon: d.type == NotificationType.pickup
              ? 'pickup'
              : d.type == NotificationType.sessionStarted
              ? 'start'
              : d.type == NotificationType.endingSoon
              ? 'ending'
              : 'reminder',
          read: d.read,
        ),
    ]..sort((a, b) => b.time.compareTo(a.time));
    final rows = items
        .where((n) => tab == 0 || n.category == categories[tab])
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader('Notifications'),
        PageBody(
          children: [
            LayoutBuilder(
              builder: (context, c) => Wrap(
                spacing: 24,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: c.maxWidth > 650 ? c.maxWidth - 170 : c.maxWidth,
                    child: SectionTabs(
                      height: 60,
                      labels: [
                        for (final category in categories)
                          '$category (${items.where((n) => category == 'All' || n.category == category).length})',
                      ],
                      index: tab,
                      onChanged: (v) => setState(() => tab = v),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _read(),
                    child: const Text(
                      'Mark all as read',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (!widget.store.deliveryService.configured)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  widget.store.shared
                      ? 'In-app notifications are persisted in Firestore. Background push and SMS are unavailable on this Spark setup.'
                      : 'Push/SMS providers are not configured. Delivery attempts are recorded locally; no messages are sent.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            AppPanel(
              child: Column(
                children: [
                  for (final n in rows)
                    InkWell(
                      onTap: () => _read(n.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: StaffTheme.line),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: switch (n.icon) {
                                  'start' => const Color(0xFFFFBFCB),
                                  'ending' => const Color(0xFFDBF6B4),
                                  'pickup' => const Color(0xFFE2BAF2),
                                  'relative' => const Color(0xFFFFE19B),
                                  _ => const Color(0xFFC8E1EE),
                                },
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                n.icon == 'system'
                                    ? Icons.fact_check_outlined
                                    : Icons.notifications_none_rounded,
                                color: StaffTheme.navy,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          n.title,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: n.read
                                                ? FontWeight.w500
                                                : FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (!n.read) ...[
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.circle,
                                          color: StaffTheme.teal,
                                          size: 6,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    n.message,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 5),
                                  if (deliveries[n.id]
                                      case final NotificationDelivery d) ...[
                                    Text(
                                      '${d.recipientType == RecipientType.patient
                                          ? 'Patient'
                                          : d.recipientType == RecipientType.staff
                                          ? 'Staff'
                                          : 'Relative'} • ${d.channelLabel} • ${d.statusLabel}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: d.status == DeliveryStatus.failed
                                            ? Colors.deepOrange
                                            : Colors.black54,
                                      ),
                                    ),
                                    if (d.attempts.isNotEmpty &&
                                        d.attempts.last.reason.isNotEmpty)
                                      Text(
                                        d.attempts.last.reason,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    TextButton(
                                      onPressed: () => showDialog<void>(
                                        context: context,
                                        builder: (context) => AppDialog(
                                          title: 'Delivery History',
                                          width: 430,
                                          actions: [
                                            AppButton(
                                              'Close',
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                            ),
                                          ],
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Text(
                                                d.recipientName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                '${d.trigger.name} • ${shortDate(d.createdAt)} • ${sessionTime(d.createdAt)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                              for (final attempt in d.attempts)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 12,
                                                      ),
                                                  child: Text(
                                                    '${attempt.channel.name.toUpperCase()} • ${attempt.status.label}\n${attempt.reason}\n${shortDate(attempt.createdAt)} • ${sessionTime(attempt.createdAt)}',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'View attempts',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ] else
                                    Text(
                                      n.id.startsWith('N-S-')
                                          ? 'Local schedule activity • no delivery attempt'
                                          : 'Demonstration entry • no provider delivery',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              sessionTime(n.time),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('No notifications in this category.'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

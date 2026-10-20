import 'package:flutter/material.dart';
import 'package:core_shared/core_shared.dart'
    show
        SessionProgress,
        sessionTransitionAllowed,
        pauseReasonCodes,
        endReasonCodes,
        sessionReasonLabel;

import '../../widgets/planned_duration_field.dart';

import '../../models/notification_delivery.dart';
import '../../models/session.dart';
import '../../services/staff_store.dart';
import '../../theme/staff_theme.dart';
import '../../widgets/registration_details.dart';
import '../../widgets/staff_components.dart';
import '../../widgets/pickers.dart';
import '../../widgets/status_chip.dart';

Future<void> showReminderComposer(
  BuildContext context,
  StaffStore store,
  SessionRecord session,
) => showDialog<void>(
  context: context,
  builder: (_) => ReminderComposer(store: store, session: session),
);

class ReminderComposer extends StatefulWidget {
  const ReminderComposer({
    super.key,
    required this.store,
    required this.session,
  });
  final StaffStore store;
  final SessionRecord session;
  @override
  State<ReminderComposer> createState() => _ReminderComposerState();
}

class _ReminderComposerState extends State<ReminderComposer> {
  late final TextEditingController message;
  late final Set<String> selected;
  bool busy = false;
  String? error;
  List<NotificationDelivery>? results;
  @override
  void initState() {
    super.initState();
    final p = widget.store.patientFor(widget.session.patientId);
    message = TextEditingController(
      text: notificationMessage(
        NotificationType.scheduleReminder,
        p,
        widget.session,
        RecipientType.patient,
      ),
    );
    selected = widget.store.recipientsFor(p.id).map((r) => r.id).toSet();
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> send() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final sent = await widget.store.sendReminder(
        widget.session.id,
        recipientIds: selected,
        message: message.text,
      );
      if (mounted) setState(() => results = sent);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError ? e.message : 'Could not record the delivery attempt. Check notification history before trying again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.store.patientFor(widget.session.patientId);
    final s = widget.session;
    return PopScope(
      canPop: !busy,
      child: AppDialog(
        title: results == null ? 'Send Reminder' : 'Delivery Results',
        width: 490,
        actions: results == null
            ? [
                AppButton(
                  'Cancel',
                  onPressed: busy ? null : () => Navigator.pop(context),
                ),
                AppButton(
                  busy ? 'Sending…' : 'Send Reminder',
                  primary: true,
                  onPressed: busy ? null : send,
                ),
              ]
            : [AppButton('Close', onPressed: () => Navigator.pop(context))],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              p.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              '${shortDate(s.start)} • ${sessionTime(s.start)}\n${s.room} • ${s.batch}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            if (!widget.store.deliveryService.configured)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  widget.store.shared
                      ? 'In-app notifications are persisted in Firestore. Background push and SMS are unavailable on this Spark setup.'
                      : 'Push/SMS providers are not configured. Attempts will be recorded as unavailable; no message will be sent.',
                  style: TextStyle(fontSize: 12, color: Colors.deepOrange),
                ),
              ),
            if (results == null) ...[
              const Text(
                'RECIPIENTS',
                style: TextStyle(
                  color: StaffTheme.navy,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              for (final r in widget.store.recipientsFor(p.id))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: selected.contains(r.id),
                        onChanged: busy
                            ? null
                            : (value) => setState(() {
                                if (value == true) {
                                  selected.add(r.id);
                                } else {
                                  selected.remove(r.id);
                                }
                              }),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r.type == RecipientType.patient ? 'Patient' : 'Designated Relative'} • ${r.name}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(r.phone, style: const TextStyle(fontSize: 12)),
                            RegistrationDetails(
                              recipient: r,
                              store: widget.store,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.store.recipientsFor(p.id).isEmpty)
                const Text('No recipients have notifications enabled.'),
              const SizedBox(height: 14),
              const Text(
                'MESSAGE',
                style: TextStyle(
                  color: StaffTheme.navy,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('reminder-message'),
                controller: message,
                maxLines: 4,
                enabled: !busy,
                decoration: const InputDecoration(hintText: 'Reminder message'),
              ),
            ] else
              for (final result in results!) ...[
                const SizedBox(height: 12),
                Text(
                  result.recipientName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final attempt in result.attempts)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      '${attempt.channel == DeliveryChannel.inApp
                          ? 'In-app notification'
                          : attempt.channel == DeliveryChannel.push
                          ? 'Push Notification'
                          : 'SMS'} • ${attempt.status.label}\n${attempt.reason}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> showSessionManagement(
  BuildContext context,
  StaffStore store,
  SessionRecord session, {
  bool schedule = false,
  SessionStatus? initialStatus,
}) => showDialog<void>(
  context: context,
  builder: (_) => SessionManagement(
    store: store,
    session: session,
    schedule: schedule,
    initialStatus: initialStatus,
  ),
);

class SessionManagement extends StatefulWidget {
  const SessionManagement({
    super.key,
    required this.store,
    required this.session,
    this.schedule = false,
    this.initialStatus,
  });
  final StaffStore store;
  final SessionRecord session;
  final bool schedule;
  final SessionStatus? initialStatus;
  @override
  State<SessionManagement> createState() => _SessionManagementState();
}

class _SessionManagementState extends State<SessionManagement> {
  late SessionStatus status;
  late String batch;
  late DateTime start;
  DateTime? end;
  late int plannedDuration;
  late final TextEditingController room;
  bool busy = false;
  String? error;
  String? reasonCode;
  final note = TextEditingController();
  late Future<List<Map<String, dynamic>>> history;
  @override
  void initState() {
    super.initState();
    history = widget.store.sessionHistory(widget.session.id);
    status = widget.initialStatus ?? widget.session.status;
    plannedDuration = widget.session.plannedDurationMinutes ?? 240;
    batch = widget.session.batch;
    start = widget.session.start;
    end = widget.session.expectedEnd;
    room = TextEditingController(text: widget.session.room);
  }

  @override
  void dispose() {
    room.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save({bool cancel = false}) async {
    if (busy) return;
    if (room.text.trim().isEmpty) {
      setState(() => error = 'Enter an assigned room.');
      return;
    }
    final target = cancel ? SessionStatus.cancelled : status;
    if ([
          SessionStatus.paused,
          SessionStatus.endedEarly,
          SessionStatus.cancelled,
        ].contains(target) &&
        reasonCode == null) {
      setState(() => error = 'Select an operational reason.');
      return;
    }
    if (!widget.schedule && !cancel) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AppDialog(
          title: 'Update Session Status?',
          width: 420,
          actions: [
            AppButton('Cancel', onPressed: () => Navigator.pop(context, false)),
            AppButton(
              'Confirm',
              primary: true,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.store.patientFor(widget.session.patientId).name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusChip(widget.session.status),
                  const Icon(Icons.arrow_forward, size: 19),
                  StatusChip(status),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'This will update the dialysis session and may generate notifications for designated recipients.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    String feedback =
        'Schedule updated. Check Notifications for delivery results.';
    try {
      if (cancel) {
        await widget.store.changeSessionStatus(
          widget.session.id,
          SessionStatus.cancelled,
          expectedRevision: widget.session.revision,
          reasonCode: reasonCode,
          note: note.text,
        );
      } else if (widget.schedule) {
        await widget.store.updateSchedule(
          widget.session.id,
          start: start,
          room: room.text.trim(),
          batch: batch,
          plannedDurationMinutes: plannedDuration,
        );
      } else {
        final result = await widget.store.changeSessionStatus(
          widget.session.id,
          status,
          expectedEnd: end,
          expectedRevision: widget.session.revision,
          reasonCode: reasonCode,
          note: note.text,
        );
        feedback =
            result.deliveryWarning ??
            (result.notificationCount > 0
                ? 'Session status updated. Notification attempts recorded; check Notifications for results.'
                : 'Session status updated.');
      }
      if (mounted) {
        Navigator.pop(context);
        showNotice(context, feedback);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message
              : 'Unable to update the session. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AppDialog(
      title: widget.schedule ? 'Edit Schedule' : 'Manage Dialysis Session',
      width: 440,
      actions: [
        if (widget.schedule)
          AppButton(
            'Cancel Schedule',
            onPressed: busy
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AppDialog(
                        title: 'Cancel Schedule?',
                        actions: [
                          AppButton(
                            'Keep Schedule',
                            onPressed: () => Navigator.pop(context, false),
                          ),
                          AppButton(
                            'Confirm Cancellation',
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ],
                        child: const Text(
                          'This will cancel the session and generate notifications for the patient and designated relatives.',
                        ),
                      ),
                    );
                    if (confirmed == true && mounted) await save(cancel: true);
                  },
          ),
        AppButton(
          widget.schedule ? 'Close' : 'Cancel',
          onPressed: busy ? null : () => Navigator.pop(context),
        ),
        AppButton(
          busy
              ? (widget.schedule ? 'Saving…' : 'Updating…')
              : (widget.schedule ? 'Save' : 'Update Status'),
          primary: true,
          onPressed:
              busy ||
                  (!widget.schedule &&
                      status == widget.session.status &&
                      end == widget.session.expectedEnd)
              ? null
              : save,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.store.patientFor(widget.session.patientId).name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          if (!widget.schedule) ...[
            Text(
              'Patient ID: ${widget.store.publicIdFor(widget.session.patientId)}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            Text(
              '${widget.session.batch} • ${widget.session.room}\nScheduled: ${shortDate(widget.session.start)} • ${sessionTime(widget.session.start)}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 16),
          if (widget.schedule) ...[
            Builder(
              builder: (anchor) => SelectorButton(
                label: '${shortDate(start)} • ${sessionTime(start)}',
                icon: Icons.calendar_month_outlined,
                onPressed: busy
                    ? null
                    : () async {
                        final date = await chooseDate(
                          anchor,
                          start,
                          time: true,
                        );
                        if (date != null && mounted) {
                          setState(() => start = date);
                        }
                      },
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: room,
              decoration: const InputDecoration(labelText: 'Assigned room'),
              enabled: !busy,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: batch,
              items: [
                for (final b in widget.store.batches.where(
                  (b) => b != 'All Batches',
                ))
                  DropdownMenuItem(value: b, child: Text(b)),
              ],
              onChanged: busy ? null : (b) => setState(() => batch = b!),
            ),
            const SizedBox(height: 14),
            PlannedDurationField(
              value: plannedDuration,
              onChanged: busy
                  ? null
                  : (v) => setState(() => plannedDuration = v),
            ),
          ] else ...[
            const Text(
              'SESSION STATUS',
              style: TextStyle(
                color: StaffTheme.navy,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Current Status',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusChip(widget.session.status),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<SessionStatus>(
              isExpanded: true,
              key: const ValueKey('session-status-selector'),
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Change Status'),
              items: [
                if (!SessionStatus.editable.contains(status))
                  DropdownMenuItem(
                    value: status,
                    enabled: false,
                    child: Text(status.label),
                  ),
                for (final value in SessionStatus.editable.where(
                  (v) => sessionTransitionAllowed(widget.session.status, v),
                ))
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: busy
                  ? null
                  : (value) => setState(() {
                      status = value!;
                      reasonCode = null;
                    }),
            ),
            const SizedBox(height: 16),
            SessionProgress(session: widget.session),
            const SizedBox(height: 12),
            const Text(
              'Only authorized Staff can complete the session or mark it Ready for Pick Up. The timer does not change status.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          if (([
                    SessionStatus.paused,
                    SessionStatus.endedEarly,
                    SessionStatus.cancelled,
                  ].contains(status) &&
                  status != widget.session.status) ||
              widget.schedule) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              key: ValueKey(status),
              initialValue: reasonCode,
              decoration: const InputDecoration(
                labelText: 'Operational reason (Staff only)',
              ),
              items: [
                for (final r
                    in status == SessionStatus.paused
                        ? pauseReasonCodes
                        : endReasonCodes)
                  DropdownMenuItem(
                    value: r,
                    child: Text(
                      sessionReasonLabel(r),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: busy ? null : (r) => setState(() => reasonCode = r),
            ),
            TextField(
              controller: note,
              enabled: !busy,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Internal note (optional, Staff only)',
              ),
            ),
          ],
          if (!widget.schedule)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: history,
              builder: (context, snapshot) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Session History',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (snapshot.connectionState != ConnectionState.done)
                    const LinearProgressIndicator(),
                  if (snapshot.connectionState == ConnectionState.done &&
                      !snapshot.hasError &&
                      (snapshot.data?.isEmpty ?? true))
                    const Text('No events recorded for this session.'),
                  if (snapshot.hasError)
                    const Text(
                      'Unable to load history. Reopen this panel to retry.',
                    ),
                  for (final e in snapshot.data ?? [])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '${e['type']} • ${e['toStatus']} • ${DateTime.tryParse(e['timestamp']?.toString() ?? '')?.toLocal() ?? 'Not recorded'}\nStaff: ${e['actorUid']}${e['reasonCode'] == '' ? '' : '\n${sessionReasonLabel(e['reasonCode'] as String)}'}${e['note'] == '' ? '' : '\n${e['note']}'}',
                      ),
                    ),
                ],
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    ),
  );
}

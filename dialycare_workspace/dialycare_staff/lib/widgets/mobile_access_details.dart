import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/notifications/providers.dart';
import '../services/staff_store.dart';
import '../theme/staff_theme.dart';

class MobileAccessDetails extends StatefulWidget {
  const MobileAccessDetails({
    super.key,
    required this.recipient,
    required this.store,
    this.manageAccess = true,
    this.allowActivation = true,
  });
  final NotificationRecipient recipient;
  final StaffStore store;
  final bool manageAccess;
  final bool allowActivation;
  @override
  State<MobileAccessDetails> createState() => _MobileAccessDetailsState();
}

class _MobileAccessDetailsState extends State<MobileAccessDetails> {
  late MobileAccount account = widget.recipient.mobileAccount;
  bool busy = false;
  @override
  void didUpdateWidget(covariant MobileAccessDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipient != widget.recipient) {
      account = widget.recipient.mobileAccount;
    }
  }

  String get idLabel =>
      widget.recipient.type.name == 'patient' ? 'Patient ID' : 'Relative ID';
  String dateTime(DateTime date) =>
      '${shortDate(date.toLocal())} • ${TimeOfDay.fromDateTime(date.toLocal()).format(context)}';
  Future<void> issue() async {
    final regenerating =
        account.status == MobileAccountStatus.activationPending;
    final relative = widget.recipient.type.name == 'relative';
    bool working = false;
    String? pin, notice;
    DateTime? expiresAt;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(
            pin == null
                ? (regenerating
                      ? 'Regenerate Temporary PIN?'
                      : 'Create Mobile Access')
                : (regenerating
                      ? 'New Temporary PIN'
                      : relative
                      ? 'Relative Mobile Access Created'
                      : 'Mobile Access Created'),
          ),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipient.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SelectableText('$idLabel: ${widget.recipient.displayId}'),
                  if (relative)
                    Text(
                      'Linked Patient: ${widget.store.publicIdFor(widget.recipient.patientId)}',
                    ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 16),
                  if (pin == null && regenerating)
                    const Text(
                      'The previous Temporary PIN will immediately stop working.',
                    ),
                  if (pin == null)
                    const Text(
                      'Generate a one-time Temporary PIN for first-time DialyCare activation. The PIN expires after 24 hours.',
                    ),
                  if (pin != null) ...[
                    const Text(
                      'Temporary PIN',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      pin!,
                      style: const TextStyle(
                        fontSize: 28,
                        letterSpacing: 4,
                        fontWeight: FontWeight.bold,
                        color: StaffTheme.navy,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: pin!)),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Temporary PIN'),
                    ),
                    const Text('Account Status: Activation Pending'),
                    if (expiresAt != null)
                      Text('Expires: ${dateTime(expiresAt!)}'),
                    if (regenerating)
                      const Text('The previous PIN is no longer valid.'),
                    const SizedBox(height: 12),
                    const Text(
                      'Share this ID and PIN directly with the approved person. The PIN is shown once; they will choose their own password in Mobile.',
                    ),
                  ],
                  if (notice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        notice!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: working ? null : () => Navigator.pop(dialogContext),
              child: Text(pin == null ? 'Cancel' : 'Done'),
            ),
            if (pin == null)
              FilledButton(
                onPressed: working
                    ? null
                    : () async {
                        setDialog(() => working = true);
                        try {
                          final result = await widget.store.issueActivation!(
                            widget.recipient.type.name,
                            widget.recipient.patientId,
                            widget.recipient.id,
                          );
                          expiresAt = DateTime.tryParse(
                            result['expiresAt'] as String? ?? '',
                          );
                          if (mounted) {
                            setState(
                              () => account = MobileAccount(
                                activationExpiresAt: expiresAt,
                                status: MobileAccountStatus.activationPending,
                              ),
                            );
                          }
                          if (context.mounted) {
                            setDialog(() => pin = result['pin'] as String);
                          }
                          await widget.store.refreshShared();
                        } on BackendException catch (e) {
                          if (context.mounted) {
                            setDialog(() => notice = e.message);
                          }
                        } catch (_) {
                          if (context.mounted) {
                            setDialog(
                              () => notice = 'Unable to create Mobile Access. Refresh the saved record and check your connection.',
                            );
                          }
                        } finally {
                          if (context.mounted) setDialog(() => working = false);
                        }
                      },
                child: Text(
                  working
                      ? 'Creating Mobile Access…'
                      : regenerating
                      ? 'Regenerate'
                      : 'Create Mobile Access',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> cancelPending() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Mobile Access?'),
        content: const Text(
          'The pending Temporary PIN will stop working. The care record and history remain saved. You can create new Mobile Access later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep pending access'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Mobile Access'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.store.cancelMobileAccess!(
        widget.recipient.type.name,
        widget.recipient.id,
      );
      if (mounted) setState(() => account = const MobileAccount());
      await widget.store.refreshShared();
    } catch (_) {
      showError('Unable to cancel pending access. Refresh and try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void showError(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> change(bool enabled) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          enabled ? 'Restore Mobile Access?' : 'Disable Mobile Access?',
        ),
        content: Text(
          enabled ? 'Restore this approved owner’s access?' : 'Protected access will be blocked. Care records and history remain saved. This does not reset the password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.store.changeMobileAccess!(
        widget.recipient.type.name,
        widget.recipient.id,
        enabled,
      );
      if (mounted) {
        setState(
          () => account = MobileAccount(
            status: enabled
                ? MobileAccountStatus.active
                : MobileAccountStatus.disabled,
            activatedAt: account.activatedAt,
          ),
        );
      }
      await widget.store.refreshShared();
    } catch (_) {
      showError('Unable to change Mobile Access. Refresh and try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.recipient.type.name == 'relative'
            ? 'Relative Mobile Access'
            : 'Mobile Access',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      Text('Account Status: ${account.label}'),
      if (widget.manageAccess &&
          account.status == MobileAccountStatus.activationPending) ...[
        if (account.activationExpiresAt != null)
          Text('Activation Expires: ${dateTime(account.activationExpiresAt!)}'),
        const Text(
          'Temporary PIN was shown when Mobile Access was created. If the PIN was lost, regenerate it.',
        ),
      ],
      if (account.activatedAt != null)
        Text(
          'Activated: ${dateTime(account.activatedAt!)}',
          style: const TextStyle(fontSize: 11),
        ),
      if (widget.manageAccess && widget.store.shared) ...[
        if (widget.allowActivation &&
            widget.store.issueActivation != null &&
            [
              MobileAccountStatus.notActivated,
              MobileAccountStatus.activationPending,
            ].contains(account.status))
          TextButton(
            onPressed: busy ? null : issue,
            child: Text(
              account.status == MobileAccountStatus.activationPending
                  ? 'Regenerate Temporary PIN'
                  : 'Create Mobile Access',
            ),
          ),
        if (widget.store.cancelMobileAccess != null &&
            account.status == MobileAccountStatus.activationPending)
          TextButton(
            onPressed: busy ? null : cancelPending,
            child: const Text('Cancel Mobile Access'),
          ),
        if (widget.store.changeMobileAccess != null &&
            [
              MobileAccountStatus.active,
              MobileAccountStatus.disabled,
            ].contains(account.status))
          TextButton(
            onPressed: busy
                ? null
                : () => change(account.status == MobileAccountStatus.disabled),
            child: Text(
              busy
                  ? 'Saving…'
                  : account.status == MobileAccountStatus.disabled
                  ? 'Restore Mobile Access'
                  : 'Disable Mobile Access',
            ),
          ),
      ],
      if (!widget.manageAccess)
        const Text(
          'Manage Mobile Access in Patients → Patient Details.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      const SizedBox(height: 6),
    ],
  );
}

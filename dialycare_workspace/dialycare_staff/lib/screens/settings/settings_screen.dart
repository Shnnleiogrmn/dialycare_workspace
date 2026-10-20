import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';

import '../../services/staff_store.dart';
import '../../theme/staff_theme.dart';
import '../../widgets/staff_components.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});
  final StaffStore store;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? section;
  String auditFilter = 'All';
  bool busy = false;
  String? error;
  final name = TextEditingController(),
      contact = TextEditingController(),
      address = TextEditingController();
  @override
  void dispose() {
    name.dispose();
    contact.dispose();
    address.dispose();
    super.dispose();
  }

  void open(String value) {
    if (value == 'Help & Support') {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const HelpSupportPage(application: 'Staff'),
        ),
      );
      return;
    }
    if (value == 'Center Information') {
      name.text = widget.store.centerInformation['name'] as String? ?? '';
      contact.text = widget.store.centerInformation['contact'] as String? ?? '';
      address.text = widget.store.centerInformation['address'] as String? ?? '';
    }
    setState(() {
      section = value;
      error = null;
    });
    if (value == 'Audit Activity') {
      refresh();
    }
  }

  Future<void> refresh() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (section == 'Audit Activity') {
        await widget.store.refreshAuditActivity();
      } else {
        await widget.store.refreshShared();
      }
      if (widget.store.loadError != null) {
        throw StateError('refresh');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              error = 'Unable to refresh. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> saveCenter() async {
    if (!widget.store.isCenterAdmin ||
        widget.store.saveCenterInformation == null ||
        busy) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.saveCenterInformation!({
        'name': name.text,
        'contact': contact.text,
        'address': address.text,
      });
      await widget.store.refreshShared();
      if (mounted) showNotice(context, 'Center information saved.');
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is BackendException
              ? e.message
              : 'Unable to save center information.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget info(String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(text),
      ],
    ),
  );
  Widget content() {
    switch (section) {
      case 'Center Information':
        final editable =
            widget.store.isCenterAdmin &&
            widget.store.saveCenterInformation != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            info(
              'Center Information',
              'Your role: ${widget.store.roleLabel}. The approved Center Admin manages the information shown below.',
            ),
            for (final pair in [
              ('Dialysis Center Name', name),
              ('Contact Number', contact),
              ('Address', address),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextField(
                  controller: pair.$2,
                  readOnly: !editable,
                  maxLength: pair.$1 == 'Dialysis Center Name'
                      ? 120
                      : pair.$1 == 'Contact Number'
                      ? 40
                      : 240,
                  decoration: InputDecoration(labelText: pair.$1),
                ),
              ),
            if (editable)
              AppButton(
                busy ? 'Saving…' : 'Save Center Information',
                primary: true,
                onPressed: busy ? null : saveCenter,
              )
            else
              const Text(
                'Center information is read only for Staff. Contact your approved Center Admin to request changes.',
              ),
          ],
        );
      case 'Staff Accounts':
        return info(
          'Responsibilities and account administration',
          'Staff manage Patient records, schedules, sessions, notifications, reports, and Mobile Access. Center Admin can also update center information.\n\nContact your authorized administrator to create Staff accounts, change roles, or arrange secure account recovery. These actions are not available in this screen.',
        );
      case 'Privacy & Terms':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            info(
              'Terms of Use & Privacy Notice',
              'Last Updated: $policyUpdated\nRead the current documents below. Their review status is stated in each document.',
            ),
            TextButton(
              onPressed: () => showPolicyDocument(context, privacy: false),
              child: const Text('Terms of Use'),
            ),
            TextButton(
              onPressed: () => showPolicyDocument(context, privacy: true),
              child: const Text('Privacy Notice'),
            ),
            const Text(
              'First-time Mobile activation records Terms agreement and Privacy Notice acknowledgment separately.',
            ),
          ],
        );
      case 'Audit Activity':
        final events = widget.store.auditEvents.where(
          (e) =>
              auditFilter == 'All' ||
              auditGroup(e['action'] as String) == auditFilter,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            info(
              'Activity History',
              'The latest 100 recorded account and care-record changes. Passwords, PINs, and medical details are excluded.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in [
                  'All',
                  'Patients',
                  'Relatives',
                  'Schedules',
                  'Sessions',
                  'Mobile Access',
                  'Notifications',
                  'Settings',
                ])
                  ChoiceChip(
                    label: Text(filter),
                    selected: auditFilter == filter,
                    onSelected: (_) => setState(() => auditFilter = filter),
                  ),
              ],
            ),
            TextButton.icon(
              onPressed: busy ? null : refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Activity'),
            ),
            if (events.isEmpty) const Text('No activity in this view.'),
            for (final e in events)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(auditLabels[e['action']] ?? 'Activity'),
                subtitle: Text(
                  '${e['actorRole'] == 'admin'
                      ? 'Center Admin'
                      : e['actorRole'] == 'staff'
                      ? 'Staff'
                      : e['actorRole'] == 'patient'
                      ? 'Patient'
                      : 'Relative'}\n${widget.store.auditResourceLabel(e)}\n${DateTime.tryParse(e['timestamp'] as String? ?? '')?.toLocal() ?? 'Time unavailable'} • ${e['outcome']}',
                ),
              ),
          ],
        );
      case 'Data & Backup Status':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            info(
              'Cloud Database',
              'Firebase Cloud Firestore — Patient, Relative, schedule/session, notification, access and activity records.',
            ),
            info(
              'Authentication',
              'Firebase Authentication — account identities and credentials. It is separate from the Patient record database.',
            ),
            info('Automated Backup', 'NOT CONFIGURED / NOT VERIFIED'),
            info(
              'Record lifecycle',
              'Archive preserves records and historical sessions. Restoring uses the same Patient ID. Archival is not deletion, a backup, or legal disposal. No automated legal retention/disposal service is configured.',
            ),
            info(
              'Production readiness',
              'TRUSTED BACKEND REQUIRED FOR PRODUCTION. No automatic backup protection or legal compliance is claimed. Managed backup services have not been enabled.',
            ),
          ],
        );
      case 'About DialyCare':
        return info(
          'DialyCare',
          'Application Version: $applicationVersion\n\n$dialyCareDescription',
        );
      default:
        return Column(
          children: [
            for (final item in [
              'Center Information',
              'Staff Accounts',
              'Privacy & Terms',
              'Audit Activity',
              'Data & Backup Status',
              'About DialyCare',
              'Help & Support',
            ])
              ListTile(
                title: Text(item),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(item),
              ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader('Settings'),
        PageBody(
          children: [
            AppPanel(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (section != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: busy
                            ? null
                            : () => setState(() => section = null),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('All Settings'),
                      ),
                    ),
                    Text(
                      section!,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: StaffTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  content(),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

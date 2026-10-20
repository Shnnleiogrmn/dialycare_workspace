import 'package:flutter/material.dart';

import '../../services/staff_store.dart';
import '../cloud_workspace.dart';
import '../../widgets/staff_components.dart';
import '../../theme/staff_theme.dart';

Future<void> showStaffProfile(BuildContext context, StaffStore store) async {
  final action = await showDialog<String>(
    context: context,
    builder: (context) => AppDialog(
      title: 'Your Profile',
      width: 360,
      child: Column(
        children: [
          Image.asset('assets/images/staff-avatar.png', width: 78, height: 78),
          const SizedBox(height: 10),
          Text(
            store.staffName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(store.roleLabel, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          for (final item in [
            if (!store.shared)
              ('password', 'Change Password', Icons.lock_outline),
            if (!store.shared)
              ('cloud', 'Connect care center', Icons.cloud_outlined),
            ('help', 'Help/Support', Icons.help_outline),
            ('logout', 'Log Out', Icons.logout),
          ])
            ListTile(
              dense: true,
              leading: Icon(item.$3, color: StaffTheme.navy),
              title: Text(item.$2),
              onTap: () => Navigator.pop(context, item.$1),
            ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (action == 'cloud') {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: CloudWorkspace()),
      ),
    );
    return;
  }
  if (action == 'logout') store.logOut();
  if (action == 'password') {
    await showDialog<void>(
      context: context,
      builder: (_) => PasswordDialog(store: store),
    );
  }
  if (action == 'help' && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: 'Help/Support',
        actions: [AppButton('Close', onPressed: () => Navigator.pop(context))],
        child: Text(
          store.shared
              ? 'Use Patients → Edit → Mobile Access to create a first-time ID/PIN. Settings → Help & Support provides safe diagnostics and support information. Never share passwords, PINs or Patient records in a support request. Notifications are in-app; background push and SMS are unavailable. Do not rely on DialyCare for urgent medical concerns.'
              : 'Patients: search by name, ID or contact. Add or edit personal, relative and medical information.\n\nSchedules: choose a date and batch, or add a patient to a session.\n\nSessions and reports: use the tabs and filters to inspect recorded sessions.\n\nThis workspace saves on this device. A workspace password can lock access after logout; it is not a Firebase account. Clinical and messaging services are not connected.',
        ),
      ),
    );
  }
}

class PasswordDialog extends StatefulWidget {
  const PasswordDialog({super.key, required this.store});
  final StaffStore store;
  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final current = TextEditingController(),
      next = TextEditingController(),
      confirm = TextEditingController();
  String? error;
  bool busy = false;
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (next.text != confirm.text) {
      setState(() => error = 'Passwords do not match.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.changePassword(current.text, next.text);
      if (mounted) {
        Navigator.pop(context);
        showNotice(context, 'Workspace password saved.');
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message
              : e is ArgumentError
              ? e.message.toString()
              : 'Unable to save password.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: 'Change Password',
    actions: [
      AppButton(
        'Cancel',
        onPressed: busy ? null : () => Navigator.pop(context),
        primary: false,
      ),
      AppButton(busy ? 'Saving…' : 'Save', onPressed: busy ? null : save),
    ],
    child: Column(
      children: [
        const Text(
          'Set a password for this local workspace. Use at least 8 characters.',
        ),
        const SizedBox(height: 16),
        if (widget.store.passwordHash.isNotEmpty) ...[
          TextField(
            controller: current,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: next,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New password'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: confirm,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Confirm password'),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    ),
  );
}

class WorkspaceSignIn extends StatefulWidget {
  const WorkspaceSignIn({super.key, required this.store});
  final StaffStore store;
  @override
  State<WorkspaceSignIn> createState() => _WorkspaceSignInState();
}

class _WorkspaceSignInState extends State<WorkspaceSignIn> {
  final password = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    setState(() => busy = true);
    final valid = await widget.store.signIn(password.text);
    if (mounted) {
      setState(() {
        busy = false;
        error = valid ? null : 'Incorrect workspace password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: StaffTheme.background,
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppPanel(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 100,
                  height: 100,
                  color: StaffTheme.navy,
                ),
                const SizedBox(height: 18),
                const Text(
                  'DialyCare Staff',
                  style: TextStyle(
                    fontSize: 24,
                    color: StaffTheme.navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Open your local workspace'),
                const SizedBox(height: 22),
                if (widget.store.passwordHash.isNotEmpty)
                  TextField(
                    controller: password,
                    obscureText: true,
                    onSubmitted: (_) => busy ? null : signIn(),
                    decoration: const InputDecoration(
                      labelText: 'Workspace password',
                    ),
                  ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 18),
                AppButton(
                  busy
                      ? 'Opening…'
                      : widget.store.passwordHash.isEmpty
                      ? 'Continue'
                      : 'Sign In',
                  onPressed: busy ? null : signIn,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

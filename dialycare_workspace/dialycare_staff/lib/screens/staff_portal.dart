import 'dart:async';

import 'package:core_shared/core_shared.dart' show FeedbackConcernsPage;

import 'package:flutter/material.dart';

import '../services/staff_store.dart';
import '../widgets/staff_shell.dart';
import 'dashboard/dashboard_screen.dart';
import 'patients/patients_screen.dart';
import 'schedules/schedules_screen.dart';
import 'sessions/sessions_screen.dart';
import 'notifications/notifications_screen.dart';
import 'reports/reports_screen.dart';
import 'profile/profile_dialog.dart';
import 'settings/settings_screen.dart';

class StaffPortal extends StatefulWidget {
  const StaffPortal({super.key, this.store, this.now});
  final StaffStore? store;
  final DateTime? now;
  @override
  State<StaffPortal> createState() => _StaffPortalState();
}

class _StaffPortalState extends State<StaffPortal> {
  late final StaffStore store;
  StaffPage page = StaffPage.dashboard;
  Timer? timer;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    store = widget.store ?? StaffStore();
    if (widget.store == null) {
      loading = true;
      store.load().then((_) {
        if (mounted) setState(() => loading = false);
      });
    }
    if (widget.now == null) {
      timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    if (widget.store == null) store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      if (loading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!store.signedIn) return WorkspaceSignIn(store: store);
      final screen = switch (page) {
        StaffPage.dashboard => DashboardScreen(
          store: store,
          now: widget.now ?? DateTime.now(),
          onNotifications: () => setState(() => page = StaffPage.notifications),
        ),
        StaffPage.patients => PatientsScreen(store: store),
        StaffPage.schedules => SchedulesScreen(store: store),
        StaffPage.sessions => SessionsScreen(
          store: store,
          day: widget.now ?? DateTime.now(),
        ),
        StaffPage.notifications => NotificationsScreen(store: store),
        StaffPage.reports => ReportsScreen(store: store),
        StaffPage.concerns =>
          store.concerns == null
              ? const Center(
                  child: Text(
                    'Connect to the shared workspace to manage Feedback & Concerns.',
                  ),
                )
              : FeedbackConcernsPage(service: store.concerns!, staff: true),
        StaffPage.settings => SettingsScreen(store: store),
      };
      return StaffShell(
        page: page,
        accountLabel: store.roleLabel,
        onPage: (value) => setState(() => page = value),
        onProfile: () => showStaffProfile(context, store),
        child: Column(
          children: [
            if (store.loadError != null)
              MaterialBanner(
                content: Text(store.loadError!),
                actions: [
                  TextButton(
                    onPressed: () => store.refreshShared(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            Expanded(child: screen),
          ],
        ),
      );
    },
  );
}

import 'package:flutter/material.dart';

import '../theme/staff_theme.dart';

enum StaffPage {
  dashboard,
  patients,
  schedules,
  sessions,
  notifications,
  reports,
  settings,
}

const navy = StaffTheme.navy,
    paleBlue = StaffTheme.background,
    tabBlue = StaffTheme.tab;

class StaffShell extends StatelessWidget {
  const StaffShell({
    super.key,
    required this.page,
    required this.onPage,
    required this.child,
    required this.onProfile,
    this.accountLabel = 'Staff',
  });
  final StaffPage page;
  final ValueChanged<StaffPage> onPage;
  final Widget child;
  final VoidCallback onProfile;
  final String accountLabel;
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 850;
    return Scaffold(
      appBar: compact
          ? AppBar(
              title: const Text('DialyCare Staff'),
              backgroundColor: Colors.white,
            )
          : null,
      drawer: compact
          ? Drawer(
              width: 248,
              child: AppSidebar(
                page: page,
                onPage: (p) {
                  Navigator.pop(context);
                  onPage(p);
                },
                accountLabel: accountLabel,
                onProfile: () {
                  Navigator.pop(context);
                  onProfile();
                },
              ),
            )
          : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!compact)
              AppSidebar(
                page: page,
                onPage: onPage,
                onProfile: onProfile,
                accountLabel: accountLabel,
              ),
            Expanded(
              child: ColoredBox(
                color: page == StaffPage.dashboard || page == StaffPage.patients
                    ? StaffTheme.background
                    : Colors.white,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.page,
    required this.onPage,
    required this.onProfile,
    this.accountLabel = 'Staff',
  });
  final StaffPage page;
  final ValueChanged<StaffPage> onPage;
  final VoidCallback onProfile;
  final String accountLabel;
  @override
  Widget build(BuildContext context) {
    const items = [
      (StaffPage.dashboard, 'Dashboard', Icons.home_outlined),
      (StaffPage.patients, 'Patients', Icons.groups_outlined),
      (StaffPage.schedules, 'Schedules', Icons.calendar_month_outlined),
      (StaffPage.sessions, 'Sessions', Icons.assignment_outlined),
      (
        StaffPage.notifications,
        'Notification',
        Icons.notifications_none_rounded,
      ),
      (StaffPage.reports, 'Reports', Icons.receipt_long_outlined),
      (StaffPage.settings, 'Settings', Icons.settings_outlined),
    ];
    return SizedBox(
      width: 248,
      child: ColoredBox(
        color: StaffTheme.navy,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 22),
              child: Image.asset(
                'assets/images/logo.png',
                width: 92,
                height: 92,
                filterQuality: FilterQuality.high,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Material(
                        color: page == item.$1
                            ? StaffTheme.selected
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(26),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(26),
                          onTap: () => onPage(item.$1),
                          child: SizedBox(
                            height: 52,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  Icon(item.$3, color: Colors.white, size: 28),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Text(
                                      item.$2,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
              child: Material(
                color: const Color(0xFF2B6C94),
                child: InkWell(
                  onTap: onProfile,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 15,
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/staff-avatar.png',
                          width: 49,
                          height: 49,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            accountLabel,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

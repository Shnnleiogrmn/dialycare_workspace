import 'package:flutter/material.dart';

enum StaffPage { dashboard, patients, schedules, sessions, notifications, reports }
const navy = Color(0xFF004A78);
const paleBlue = Color(0xFFEFFEFF);
const tabBlue = Color(0xFFB1CBDB);

class StaffShell extends StatelessWidget {
  const StaffShell({super.key, required this.page, required this.onPage, required this.child, required this.onProfile});
  final StaffPage page;
  final ValueChanged<StaffPage> onPage;
  final Widget child;
  final VoidCallback onProfile;
  @override
  Widget build(BuildContext context) => Scaffold(body: Row(children: [_Sidebar(page: page, onPage: onPage, onProfile: onProfile), Expanded(child: Container(color: page == StaffPage.dashboard || page == StaffPage.patients ? paleBlue : Colors.white, child: child))]));
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.page, required this.onPage, required this.onProfile});
  final StaffPage page;
  final ValueChanged<StaffPage> onPage;
  final VoidCallback onProfile;
  @override
  Widget build(BuildContext context) {
    const items = [(StaffPage.dashboard, 'DashBoard', Icons.home_outlined), (StaffPage.patients, 'Patients', Icons.groups_outlined), (StaffPage.schedules, 'Schedules', Icons.calendar_month_outlined), (StaffPage.sessions, 'Sessions', Icons.assignment_outlined), (StaffPage.notifications, 'Notification', Icons.notifications_none_rounded), (StaffPage.reports, 'Reports', Icons.receipt_long_outlined)];
    return Container(width: 244, color: navy, padding: const EdgeInsets.fromLTRB(14, 18, 10, 16), child: Column(children: [
      const _Brand(), const SizedBox(height: 34),
      for (final item in items) ...[_NavItem(label: item.$2, icon: item.$3, selected: page == item.$1, onTap: () => onPage(item.$1)), const SizedBox(height: 10)],
      const Spacer(), InkWell(onTap: onProfile, child: Container(height: 84, color: const Color(0xFF2B6C94), padding: const EdgeInsets.all(12), child: const Row(children: [CircleAvatar(radius: 27, backgroundColor: Color(0xFFB5D3E5), child: Icon(Icons.person, color: Color(0xFF9A2A12), size: 38)), SizedBox(width: 13), Expanded(child: Text('Staff Admin', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)))])))
    ]));
  }
}
class _Brand extends StatelessWidget { const _Brand(); @override Widget build(BuildContext context) => const Column(children: [CircleAvatar(radius: 30, backgroundColor: Color(0xFF00CBBE), child: Icon(Icons.accessibility_new_rounded, color: Colors.white, size: 50)), SizedBox(height: 4), Text('DialyCare', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700))]); }
class _NavItem extends StatelessWidget { const _NavItem({required this.label, required this.icon, required this.selected, required this.onTap}); final String label; final IconData icon; final bool selected; final VoidCallback onTap; @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(27), child: Container(height: 61, padding: const EdgeInsets.symmetric(horizontal: 19), decoration: BoxDecoration(color: selected ? const Color(0xFF6797B8) : Colors.transparent, borderRadius: BorderRadius.circular(27)), child: Row(children: [Icon(icon, color: Colors.white, size: 32), const SizedBox(width: 17), Text(label, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700))]))); }
class PageTitle extends StatelessWidget { const PageTitle(this.title, {super.key, this.showDate = true}); final String title; final bool showDate; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(36, 28, 28, 20), child: Row(children: [Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: navy)), const Spacer(), if (showDate) const Text('Mon, Sep 30, 2026', style: TextStyle(fontSize: 17, color: Colors.grey, fontWeight: FontWeight.w700))])); }
class PillTabs extends StatelessWidget { const PillTabs({super.key, required this.labels, required this.index, required this.onChanged}); final List<String> labels; final int index; final ValueChanged<int> onChanged; @override Widget build(BuildContext context) => Container(height: 104, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: tabBlue, borderRadius: BorderRadius.circular(20)), child: Row(children: [for (var i=0; i<labels.length; i++) Expanded(child: InkWell(onTap: ()=>onChanged(i), borderRadius: BorderRadius.circular(22), child: Container(alignment: Alignment.center, decoration: BoxDecoration(color: index == i ? const Color(0xFFF4F4F4) : Colors.transparent, borderRadius: BorderRadius.circular(22)), child: Text(labels[i], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))))])); }

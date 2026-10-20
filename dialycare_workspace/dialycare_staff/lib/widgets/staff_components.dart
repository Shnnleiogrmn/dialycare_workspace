import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/staff_theme.dart';

class AppButton extends StatelessWidget {
  const AppButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.primary = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 42, minWidth: 94),
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary ? StaffTheme.blue : Colors.white,
        foregroundColor: StaffTheme.navy,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );
}

class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.shadow = true,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool shadow;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(StaffTheme.radius),
      border: Border.all(color: StaffTheme.line),
      boxShadow: shadow ? StaffTheme.shadow : null,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(StaffTheme.radius),
      child: Material(
        color: Colors.transparent,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.date = false});
  final String title;
  final bool date;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 12,
      spacing: 20,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: StaffTheme.navy,
          ),
        ),
        if (date)
          Text(
            fullDate(DateTime.now()),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    ),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(28, 0, 28, 28),
  });
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Expanded(
    child: SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search patient by name, ID, or contact',
  });
  final ValueChanged<String> onChanged;
  final String hint;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, size: 22),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
      ),
    ),
  );
}

class SectionTabs extends StatelessWidget {
  const SectionTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.color = StaffTheme.tab,
    this.height = 76,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final Color color;
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: i == index
                    ? const Color(0xFFF6F7F7)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onChanged(i),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: height <= 60 ? 14 : 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.label,
    required this.count,
    this.people = true,
    this.icon = Icons.groups_outlined,
    this.color = StaffTheme.navy,
  });
  final String label;
  final int count;
  final bool people;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => AppPanel(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: SizedBox(
      height: 84,
      child: Row(
        children: [
          if (!people) ...[
            Icon(icon, color: color, size: 36),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (people)
            SizedBox(
              width: 54,
              height: 36,
              child: Stack(
                children: [
                  for (var i = 0; i < 3; i++)
                    Positioned(
                      left: i * 15.0,
                      top: 6,
                      child: Image.asset(
                        'assets/images/${i == 0
                            ? 'patient-avatar-female'
                            : i == 1
                            ? 'patient-avatar-male'
                            : 'staff-avatar'}.png',
                        width: 30,
                        height: 30,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class SummaryGrid extends StatelessWidget {
  const SummaryGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns = c.maxWidth >= children.length * 190
          ? children.length
          : c.maxWidth >= 410
          ? 2
          : 1;
      final width = (c.maxWidth - 18 * (columns - 1)) / columns;
      return Wrap(
        spacing: 18,
        runSpacing: 18,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class TableColumn {
  const TableColumn(this.title, this.flex);
  final String title;
  final int flex;
}

class DialyCareTable extends StatelessWidget {
  const DialyCareTable({
    super.key,
    required this.columns,
    required this.rows,
    this.minWidth = 820,
    this.striped = false,
    this.headerColor = StaffTheme.blue,
    this.rowHeight = StaffTheme.rowHeight,
    this.empty = 'No records found.',
  });
  final List<TableColumn> columns;
  final List<List<Widget>> rows;
  final double minWidth, rowHeight;
  final bool striped;
  final Color headerColor;
  final String empty;
  Widget _row(List<Widget> cells) => Row(
    children: [
      for (var i = 0; i < columns.length; i++)
        Expanded(
          flex: columns[i].flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Center(child: cells[i]),
          ),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: math.max(c.maxWidth, minWidth),
        child: Column(
          children: [
            Container(
              height: 54,
              color: headerColor,
              child: _row([
                for (final col in columns)
                  Text(
                    col.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
              ]),
            ),
            if (rows.isEmpty)
              Padding(padding: const EdgeInsets.all(36), child: Text(empty)),
            for (var i = 0; i < rows.length; i++)
              Container(
                height: rowHeight,
                decoration: BoxDecoration(
                  color: striped && i.isOdd ? StaffTheme.gray : Colors.white,
                  border: striped
                      ? null
                      : const Border(
                          bottom: BorderSide(
                            color: Color(0xFFE5E8EB),
                            width: .7,
                          ),
                        ),
                ),
                child: _row(rows[i]),
              ),
          ],
        ),
      ),
    ),
  );
}

class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.width = 450,
  });
  final String title;
  final Widget child;
  final List<Widget> actions;
  final double width;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(22),
    backgroundColor: Colors.transparent,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: width,
        maxHeight: MediaQuery.sizeOf(context).height - 60,
      ),
      child: AppPanel(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  color: StaffTheme.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: StaffTheme.blue),
              const SizedBox(height: 12),
              child,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 10,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

void showNotice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

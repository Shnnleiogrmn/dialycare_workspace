import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/staff_theme.dart';
import 'staff_components.dart';

Future<T?> showAnchoredPanel<T>(
  BuildContext anchor, {
  required WidgetBuilder builder,
  double width = 320,
  double height = 400,
}) {
  return showGeneralDialog<T>(
    context: anchor,
    barrierDismissible: true,
    barrierLabel: 'Close popup',
    barrierColor: const Color(0x08000000),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (context, animation, secondary) => LayoutBuilder(
      builder: (context, c) {
        final render = anchor.findRenderObject();
        final rect = render is RenderBox && render.hasSize
            ? render.localToGlobal(Offset.zero) & render.size
            : Rect.fromLTWH(c.maxWidth / 2, c.maxHeight / 2, 0, 0);
        final w = math.min(width, c.maxWidth - 32),
            h = math.min(height, c.maxHeight - 32);
        final x = rect.right - w < 16
            ? rect.left.clamp(16.0, math.max(16.0, c.maxWidth - w - 16))
            : (rect.right - w).clamp(16.0, math.max(16.0, c.maxWidth - w - 16));
        final y =
            (rect.bottom + h + 8 < c.maxHeight
                    ? rect.bottom + 8
                    : rect.top - h - 8)
                .clamp(16.0, math.max(16.0, c.maxHeight - h - 16));
        return Stack(
          children: [
            Positioned(
              left: x.toDouble(),
              top: y.toDouble(),
              width: w,
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: h),
                  child: AppPanel(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(child: builder(context)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

Widget popupActions(BuildContext context, VoidCallback onSet) => Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
    ),
    FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: StaffTheme.teal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      onPressed: onSet,
      child: const Text('Set'),
    ),
  ],
);
Future<String?> chooseOption(
  BuildContext anchor, {
  required String title,
  required List<String> options,
  required String value,
  int columns = 1,
}) {
  var selection = value;
  return showAnchoredPanel<String>(
    anchor,
    width: columns == 2 ? 310 : 240,
    height: columns == 2 ? 260 : 330,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: StaffTheme.navy,
            ),
          ),
          const SizedBox(height: 10),
          for (var row = 0; row < (options.length / columns).ceil(); row++)
            Row(
              children: [
                for (var col = 0; col < columns; col++)
                  if (row * columns + col < options.length)
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(
                          () => selection = options[row * columns + col],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                selection == options[row * columns + col]
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                size: 18,
                                color: StaffTheme.teal,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  options[row * columns + col],
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          const SizedBox(height: 10),
          popupActions(context, () => Navigator.pop(context, selection)),
        ],
      ),
    ),
  );
}

class SelectorButton extends StatelessWidget {
  const SelectorButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.keyboard_arrow_down,
    this.width,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final double? width;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black54,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        side: const BorderSide(color: StaffTheme.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label, maxLines: 2)),
          const SizedBox(width: 8),
          Icon(icon, size: 19),
        ],
      ),
    ),
  );
}

Future<DateTime?> chooseDate(
  BuildContext anchor,
  DateTime initial, {
  bool time = false,
  bool birth = false,
}) {
  var picked = initial;
  var hour = initial.hour;
  var minute = initial.minute;
  return showAnchoredPanel<DateTime>(
    anchor,
    width: 350,
    height: time ? 485 : 395,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            time
                ? 'Date & Time'
                : birth
                ? 'Date of Birth'
                : 'Choose date',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: StaffTheme.navy,
            ),
          ),
          SizedBox(
            height: 270,
            child: CalendarDatePicker(
              initialDate: initial,
              firstDate: DateTime(1900),
              lastDate: birth ? DateTime.now() : DateTime(2100),
              onDateChanged: (d) => picked = d,
            ),
          ),
          if (time) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: hour,
                    decoration: const InputDecoration(labelText: 'Hour'),
                    items: [
                      for (var h = 0; h < 24; h++)
                        DropdownMenuItem(
                          value: h,
                          child: Text(
                            '${h % 12 == 0 ? 12 : h % 12} ${h < 12 ? 'AM' : 'PM'}',
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => hour = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: minute,
                    decoration: const InputDecoration(labelText: 'Minute'),
                    items: [
                      for (var m = 0; m < 60; m++)
                        DropdownMenuItem(
                          value: m,
                          child: Text(m.toString().padLeft(2, '0')),
                        ),
                    ],
                    onChanged: (v) => setState(() => minute = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          popupActions(
            context,
            () => Navigator.pop(
              context,
              DateTime(
                picked.year,
                picked.month,
                picked.day,
                time ? hour : 0,
                time ? minute : 0,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<DateTimeRange?> chooseDateRange(
  BuildContext anchor,
  DateTimeRange initial,
) {
  var start = initial.start, end = initial.end, selectEnd = false;
  return showAnchoredPanel<DateTimeRange>(
    anchor,
    width: 370,
    height: 445,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Date range',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: StaffTheme.navy,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => selectEnd = false),
                  child: Text(
                    'From\n${shortDate(start)}',
                    style: TextStyle(
                      fontWeight: !selectEnd
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => selectEnd = true),
                  child: Text(
                    'To\n${shortDate(end)}',
                    style: TextStyle(
                      fontWeight: selectEnd
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 270,
            child: CalendarDatePicker(
              initialDate: initial.start,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
              onDateChanged: (date) => setState(() {
                if (selectEnd) {
                  end = date;
                } else {
                  start = date;
                  selectEnd = true;
                }
              }),
            ),
          ),
          popupActions(
            context,
            () => Navigator.pop(
              context,
              DateTimeRange(
                start: start.isBefore(end) ? start : end,
                end: end.isAfter(start) ? end : start,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

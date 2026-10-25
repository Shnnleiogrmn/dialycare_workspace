import 'package:flutter/material.dart';

String historyRangeDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// A bounded range calendar with the navy/teal styling of the Staff pickers.
/// Selection stays local until Apply, so dismissal never changes the filter.
Future<DateTimeRange?> showCompactDateRangePicker({
  required BuildContext context,
  DateTimeRange? initialDateRange,
  required DateTime firstDate,
  required DateTime lastDate,
}) => showDialog<DateTimeRange>(
  context: context,
  builder: (_) => _RangeCalendar(
    initial: initialDateRange,
    first: DateUtils.dateOnly(firstDate),
    last: DateUtils.dateOnly(lastDate),
  ),
);

class _RangeCalendar extends StatefulWidget {
  const _RangeCalendar({this.initial, required this.first, required this.last});
  final DateTimeRange? initial;
  final DateTime first, last;
  @override
  State<_RangeCalendar> createState() => _RangeCalendarState();
}

class _RangeCalendarState extends State<_RangeCalendar> {
  static const navy = Color(0xff0b3764), teal = Color(0xff009e99);
  DateTime? start, end;
  late DateTime month;
  bool selectingEnd = false;

  @override
  void initState() {
    super.initState();
    start = widget.initial == null
        ? null
        : DateUtils.dateOnly(widget.initial!.start);
    end = widget.initial == null
        ? null
        : DateUtils.dateOnly(widget.initial!.end);
    final today = DateUtils.dateOnly(DateTime.now());
    final visible =
        start ??
        (today.isAfter(widget.last)
            ? widget.last
            : today.isBefore(widget.first)
            ? widget.first
            : today);
    month = DateTime(visible.year, visible.month);
  }

  void select(DateTime date) => setState(() {
    if (!selectingEnd || start == null) {
      start = date;
      end = null;
      selectingEnd = true;
    } else {
      if (date.isBefore(start!)) {
        end = start;
        start = date;
      } else {
        end = date;
      }
      selectingEnd = false;
    }
  });

  @override
  Widget build(BuildContext context) {
    final locale = MaterialLocalizations.of(context);
    final offset = (month.weekday % 7 - locale.firstDayOfWeekIndex + 7) % 7;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final previous = DateTime(month.year, month.month - 1);
    final next = DateTime(month.year, month.month + 1);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        key: const ValueKey('compact-range-panel'),
        constraints: const BoxConstraints(maxWidth: 370),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Date range',
                  style: TextStyle(
                    color: navy,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      'From: ${start == null ? 'Select date' : historyRangeDate(start!)}',
                      style: const TextStyle(color: navy),
                    ),
                    Text(
                      'To: ${end == null ? 'Select date' : historyRangeDate(end!)}',
                      style: const TextStyle(color: navy),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  selectingEnd ? 'Select end date' : 'Select start date',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed:
                          month.isAfter(
                            DateTime(widget.first.year, widget.first.month),
                          )
                          ? () => setState(() => month = previous)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        locale.formatMonthYear(month),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: navy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: next.isAfter(widget.last)
                          ? null
                          : () => setState(() => month = next),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Center(
                          child: Text(
                            locale.narrowWeekdays[(i +
                                    locale.firstDayOfWeekIndex) %
                                7],
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                for (var row = 0; row < (days + offset + 6) ~/ 7; row++)
                  Row(
                    children: [
                      for (var column = 0; column < 7; column++)
                        Expanded(
                          child: day(
                            row * 7 + column - offset + 1,
                            days,
                            locale,
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: navy),
                      onPressed: start != null && end != null
                          ? () => Navigator.pop(
                              context,
                              DateTimeRange(start: start!, end: end!),
                            )
                          : null,
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget day(int number, int days, MaterialLocalizations locale) {
    if (number < 1 || number > days) return const SizedBox(height: 44);
    final date = DateTime(month.year, month.month, number);
    final enabled = !date.isBefore(widget.first) && !date.isAfter(widget.last);
    final endpoint = date == start || date == end;
    final within =
        start != null &&
        end != null &&
        date.isAfter(start!) &&
        date.isBefore(end!);
    return Semantics(
      selected: endpoint || within,
      label: locale.formatFullDate(date),
      button: true,
      child: SizedBox(
        height: 44,
        child: Material(
          color: endpoint
              ? teal
              : within
              ? const Color(0xffe0f3f3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(endpoint ? 22 : 0),
          child: InkWell(
            key: ValueKey('range-day-${date.year}-${date.month}-$number'),
            borderRadius: BorderRadius.circular(22),
            onTap: enabled ? () => select(date) : null,
            child: Center(
              child: ExcludeSemantics(
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: !enabled
                        ? Colors.black26
                        : endpoint
                        ? Colors.white
                        : navy,
                    fontWeight: endpoint ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum ScheduleGroup {
  mwf('MWF', 'Monday • Wednesday • Friday', [1, 3, 5]),
  tths('TTHS', 'Tuesday • Thursday • Saturday', [2, 4, 6]);

  const ScheduleGroup(this.code, this.daysLabel, this.weekdays);
  final String code, daysLabel;
  final List<int> weekdays;
  String get label => this == mwf ? 'MWF' : 'TThS';
  bool includes(DateTime day) => weekdays.contains(day.weekday);
  static ScheduleGroup? parse(Object? value) => switch (value) {
    'MWF' => mwf,
    'TTHS' || 'TThS' => tths,
    _ => null,
  };
  static ScheduleGroup? forDay(DateTime day) =>
      values.where((g) => g.includes(day)).firstOrNull;
}

const plannedDurationOptions = [180, 210, 240, 270, 300];
bool validPlannedDuration(int? minutes) =>
    minutes != null && minutes >= 30 && minutes <= 720;
String durationLabel(int minutes) {
  final hours = minutes ~/ 60, rest = minutes % 60;
  return [
    if (hours > 0) '$hours hours',
    if (rest > 0) '$rest minutes',
  ].join(' ');
}

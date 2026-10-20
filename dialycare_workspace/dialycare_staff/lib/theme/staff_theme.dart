import 'package:flutter/material.dart';

abstract final class StaffTheme {
  static const navy = Color(0xFF004A78);
  static const background = Color(0xFFEFFEFF);
  static const selected = Color(0xFF6797B8);
  static const blue = Color(0xFFB5D2E2);
  static const tab = Color(0xFF9FB8C6);
  static const gray = Color(0xFFE9ECEC);
  static const teal = Color(0xFF3CB0C4);
  static const line = Color(0xFFCED4D8);
  static const radius = 16.0;
  static const rowHeight = 62.0;
  static const shadow = [
    BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(3, 5)),
  ];
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Arial',
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(seedColor: navy, primary: navy),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 15, color: Colors.black87),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: line),
      ),
    ),
  );
}

String shortDate(DateTime date) {
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

String fullDate(DateTime date) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[date.weekday - 1]}, ${shortDate(date)}';
}

String sessionTime(DateTime date) =>
    '${date.hour % 12 == 0 ? 12 : date.hour % 12}:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'AM' : 'PM'}';
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

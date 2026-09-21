import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Completed' => const Color(0xFFF6B4DF),
      'Ready for Pick Up' || 'Missed' => const Color(0xFFDDFEAE),
      'In Progress' => const Color(0xFFB4D2E3),
      _ => const Color(0xFFFFEEC0),
    };
    return Container(alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), constraints: const BoxConstraints(minWidth: 145), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24)), child: Text(status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)));
  }
}

import 'package:flutter/material.dart';

import 'package:core_shared/core_shared.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final SessionStatus status;
  @override
  Widget build(BuildContext context) {
    final color = sessionStatusBackground(status);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96, maxWidth: 174),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (status == SessionStatus.waiting) ...[
              const Icon(Icons.hourglass_empty, size: 17),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                status.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: sessionStatusForeground(status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

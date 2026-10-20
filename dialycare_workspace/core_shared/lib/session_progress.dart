import 'dart:async';

import 'package:flutter/material.dart';

import 'session.dart';
import 'schedule_group.dart';

/// Display-only clock. No repository, write callback or network subscription.
class SessionProgress extends StatefulWidget {
  const SessionProgress({
    super.key,
    required this.session,
    this.compact = false,
    this.clock,
  });
  final SessionRecord session;
  final bool compact;
  final DateTime Function()? clock;
  @override
  State<SessionProgress> createState() => _SessionProgressState();
}

class _SessionProgressState extends State<SessionProgress>
    with WidgetsBindingObserver {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    restart();
  }

  @override
  void didUpdateWidget(covariant SessionProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    restart();
  }

  void restart() {
    timer?.cancel();
    if ((widget.session.status == SessionStatus.inProgress ||
            widget.session.status == SessionStatus.paused) &&
        widget.session.actualStartedAt != null &&
        widget.session.stoppedAt == null) {
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      restart();
      if (mounted) setState(() {});
    } else {
      timer?.cancel();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String spanLabel(Duration span) =>
      '${span.inHours.toString().padLeft(2, '0')}:${(span.inMinutes % 60).toString().padLeft(2, '0')}:${(span.inSeconds % 60).toString().padLeft(2, '0')}';
  String clockTime(DateTime time) =>
      '${time.toLocal().month}/${time.toLocal().day} ${time.toLocal().hour.toString().padLeft(2, '0')}:${time.toLocal().minute.toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final s = widget.session, now = widget.clock?.call() ?? DateTime.now();
    final elapsed = s.elapsedAt(now), progress = s.progressAt(now);
    final elapsedText = elapsed == null
        ? 'Not recorded'
        : '${elapsed.inHours.toString().padLeft(2, '0')}:${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${s.stoppedAt == null ? 'Elapsed' : 'Actual Duration'}: $elapsedText',
          maxLines: widget.compact ? 1 : null,
          overflow: widget.compact ? TextOverflow.ellipsis : null,
          style: TextStyle(
            fontSize: widget.compact ? 12 : 18,
            fontWeight: FontWeight.w600,
          ),
          key: ValueKey('elapsed-${s.id}'),
        ),
        Text(
          'Planned Duration: ${s.plannedDurationMinutes == null ? 'Not recorded' : durationLabel(s.plannedDurationMinutes!)}',
          maxLines: widget.compact ? 1 : null,
          overflow: widget.compact ? TextOverflow.ellipsis : null,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (progress != null) ...[
          Text(
            '${(progress * 100).floor()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: const Color(0xFF009E9A),
              backgroundColor: const Color(0xFFE2EDF2),
            ),
          ),
        ],
        if (!widget.compact) ...[
          const SizedBox(height: 12),
          Text('Scheduled Start: ${clockTime(s.start)}'),
          Text(
            'Actual Start: ${s.actualStartedAt == null ? 'Not recorded' : clockTime(s.actualStartedAt!)}',
          ),
          if (s.status == SessionStatus.paused) ...[
            const Text(
              'Treatment is temporarily paused. The center will update the session status.',
            ),
            if (s.pausedAt != null)
              Text('Paused At: ${clockTime(s.pausedAt!)}'),
          ],
          if (s.endedAt != null) ...[
            Text('Ended At: ${clockTime(s.endedAt!)}'),
            const Text(
              'Please contact the dialysis center for additional information.',
            ),
          ],
          if (s.pauseIntervals.isNotEmpty)
            Text('Total Pause: ${spanLabel(s.totalPausedAt(now))}'),
          if (s.stoppedAt != null && s.wallClockAt(now) != null)
            Text('Wall-Clock Duration: ${spanLabel(s.wallClockAt(now)!)}'),
          if (s.completedAt != null)
            Text('Completed At: ${clockTime(s.completedAt!)}'),
          if (s.completedAt == null && s.estimatedEnd != null) ...[
            Text('Estimated End: ${clockTime(s.estimatedEnd!)}'),
            const Text(
              'Estimated end time may change based on your care session.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          if (s.status == SessionStatus.inProgress && progress == 1)
            const Text(
              'Planned duration reached. The center will update the status when the session is completed.',
              style: TextStyle(fontSize: 12),
            ),
        ],
      ],
    );
  }
}

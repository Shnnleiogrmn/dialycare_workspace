export 'package:core_shared/session.dart';

class SessionStatusUpdateResult {
  const SessionStatusUpdateResult({
    required this.changed,
    this.notificationCount = 0,
    this.deliveryWarning,
  });
  final bool changed;
  final int notificationCount;
  final String? deliveryWarning;
}

class StaffNotification {
  const StaffNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    this.read = false,
  });
  final String id, category, title, message, icon;
  final DateTime time;
  final bool read;
  StaffNotification markRead() => StaffNotification(
    id: id,
    category: category,
    title: title,
    message: message,
    time: time,
    icon: icon,
    read: true,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'title': title,
    'message': message,
    'time': time.toIso8601String(),
    'icon': icon,
    'read': read,
  };
  factory StaffNotification.fromJson(Map<String, dynamic> j) =>
      StaffNotification(
        id: j['id'] as String,
        category: j['category'] as String,
        title: j['title'] as String,
        message: j['message'] as String,
        time: DateTime.parse(j['time'] as String),
        icon: j['icon'] as String,
        read: j['read'] as bool? ?? false,
      );
}

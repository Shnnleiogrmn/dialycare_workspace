enum AppRegistrationStatus { connected, notRegistered, unavailable }

class AppRegistration {
  const AppRegistration({
    this.status = AppRegistrationStatus.notRegistered,
    this.pushToken = '',
    this.lastActivity,
    this.backendVerified = false,
    this.notificationsEnabled = true,
  });
  final AppRegistrationStatus status;
  final String pushToken;
  final DateTime? lastActivity;
  final bool backendVerified, notificationsEnabled;
  bool get hasValidPush =>
      backendVerified &&
      status == AppRegistrationStatus.connected &&
      pushToken.trim().isNotEmpty;
  String get label => switch (status) {
    AppRegistrationStatus.connected =>
      hasValidPush ? 'App Connected' : 'App Unavailable',
    AppRegistrationStatus.notRegistered => 'App Not Registered',
    AppRegistrationStatus.unavailable => 'App Unavailable',
  };
  AppRegistration invalidated() => AppRegistration(
    status: AppRegistrationStatus.unavailable,
    lastActivity: lastActivity,
    backendVerified: backendVerified,
    notificationsEnabled: notificationsEnabled,
  );
  Map<String, dynamic> toJson() => {
    'status': status.name,
    'pushToken': pushToken,
    'lastActivity': lastActivity?.toIso8601String(),
    'backendVerified': backendVerified,
    'notificationsEnabled': notificationsEnabled,
  };
  factory AppRegistration.fromJson(Map<String, dynamic>? j) => j == null
      ? const AppRegistration()
      : AppRegistration(
          status: AppRegistrationStatus.values.firstWhere(
            (v) => v.name == j['status'],
            orElse: () => AppRegistrationStatus.notRegistered,
          ),
          pushToken: j['pushToken'] as String? ?? '',
          lastActivity: DateTime.tryParse(j['lastActivity'] as String? ?? ''),
          backendVerified: j['backendVerified'] as bool? ?? false,
          notificationsEnabled: j['notificationsEnabled'] as bool? ?? true,
        );
}

enum RecipientType { patient, relative, staff }

enum NotificationType {
  concernUpdate,
  concernSubmitted,
  scheduleReminder,
  sessionStarted,
  sessionPaused,
  sessionResumed,
  sessionEndedEarly,
  sessionCompleted,
  scheduleCreated,
  endingSoon,
  pickup,
  scheduleUpdated,
  scheduleRescheduled,
  scheduleCancelled,
}

enum DeliveryChannel { push, sms, inApp }

enum DeliveryStatus {
  pending,
  sent,
  delivered,
  failed,
  fallbackSent,
  available,
}

enum NotificationTrigger { automatic, staff }

class DeliveryAttempt {
  const DeliveryAttempt({
    required this.channel,
    required this.status,
    required this.createdAt,
    this.sentAt,
    this.deliveredAt,
    this.providerId = '',
    this.reason = '',
  });
  final DeliveryChannel channel;
  final DeliveryStatus status;
  final DateTime createdAt;
  final DateTime? sentAt, deliveredAt;
  final String providerId, reason;
  Map<String, dynamic> toJson() => {
    'channel': channel.name,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'sentAt': sentAt?.toIso8601String(),
    'deliveredAt': deliveredAt?.toIso8601String(),
    'providerId': providerId,
    'reason': reason,
  };
  factory DeliveryAttempt.fromJson(Map<String, dynamic> j) => DeliveryAttempt(
    channel: DeliveryChannel.values.byName(j['channel'] as String),
    status: DeliveryStatus.values.byName(j['status'] as String),
    createdAt: DateTime.parse(j['createdAt'] as String),
    sentAt: DateTime.tryParse(j['sentAt'] as String? ?? ''),
    deliveredAt: DateTime.tryParse(j['deliveredAt'] as String? ?? ''),
    providerId: j['providerId'] as String? ?? '',
    reason: j['reason'] as String? ?? '',
  );
}

class NotificationDelivery {
  const NotificationDelivery({
    required this.id,
    required this.eventId,
    required this.patientId,
    required this.recipientId,
    required this.recipientType,
    required this.recipientName,
    required this.type,
    required this.title,
    required this.message,
    required this.trigger,
    required this.sessionId,
    required this.createdAt,
    this.attempts = const [],
    this.read = false,
  });
  final String id,
      eventId,
      patientId,
      recipientId,
      recipientName,
      title,
      message,
      sessionId;
  final RecipientType recipientType;
  final NotificationType type;
  final NotificationTrigger trigger;
  final DateTime createdAt;
  final List<DeliveryAttempt> attempts;
  final bool read;
  bool get _persistedConcern =>
      type == NotificationType.concernUpdate ||
      type == NotificationType.concernSubmitted;
  DeliveryStatus get status => attempts.isEmpty
      ? (_persistedConcern ? DeliveryStatus.available : DeliveryStatus.pending)
      : attempts.last.status;
  DeliveryChannel? get channel => attempts.isEmpty
      ? (_persistedConcern ? DeliveryChannel.inApp : null)
      : attempts.last.channel;
  String get statusLabel => switch (status) {
    DeliveryStatus.available => 'Available in app',
    DeliveryStatus.pending => 'Pending',
    DeliveryStatus.sent => 'Sent',
    DeliveryStatus.delivered => 'Delivered',
    DeliveryStatus.failed => 'Failed',
    DeliveryStatus.fallbackSent => 'Fallback Sent',
  };
  String get channelLabel => channel == DeliveryChannel.inApp
      ? 'In-app notification'
      : channel == DeliveryChannel.push
      ? 'Push Notification'
      : channel == DeliveryChannel.sms
      ? 'SMS'
      : 'Awaiting channel';
  NotificationDelivery copyWith({
    List<DeliveryAttempt>? attempts,
    bool? read,
  }) => NotificationDelivery(
    id: id,
    eventId: eventId,
    patientId: patientId,
    recipientId: recipientId,
    recipientType: recipientType,
    recipientName: recipientName,
    type: type,
    title: title,
    message: message,
    trigger: trigger,
    sessionId: sessionId,
    createdAt: createdAt,
    attempts: attempts ?? this.attempts,
    read: read ?? this.read,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'patientId': patientId,
    'recipientId': recipientId,
    'recipientType': recipientType.name,
    'recipientName': recipientName,
    'type': type.name,
    'title': title,
    'message': message,
    'trigger': trigger.name,
    'sessionId': sessionId,
    'createdAt': createdAt.toIso8601String(),
    'attempts': attempts.map((a) => a.toJson()).toList(),
    'read': read,
  };
  factory NotificationDelivery.fromJson(Map<String, dynamic> j) =>
      NotificationDelivery(
        id: j['id'] as String,
        eventId: j['eventId'] as String,
        patientId: j['patientId'] as String,
        recipientId: j['recipientId'] as String,
        recipientType: RecipientType.values.byName(
          j['recipientType'] as String,
        ),
        recipientName: j['recipientName'] as String,
        type: NotificationType.values.byName(j['type'] as String),
        title: j['title'] as String,
        message: j['message'] as String,
        trigger: NotificationTrigger.values.byName(j['trigger'] as String),
        sessionId: j['sessionId'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        attempts: ((j['attempts'] as List?) ?? [])
            .map(
              (a) =>
                  DeliveryAttempt.fromJson(Map<String, dynamic>.from(a as Map)),
            )
            .toList(),
        read: j['read'] as bool? ?? false,
      );
}

class NotificationEvent {
  const NotificationEvent({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.trigger,
    required this.createdAt,
  });
  final String id, sessionId;
  final NotificationType type;
  final NotificationTrigger trigger;
  final DateTime createdAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'type': type.name,
    'trigger': trigger.name,
    'createdAt': createdAt.toIso8601String(),
  };
  factory NotificationEvent.fromJson(Map<String, dynamic> j) =>
      NotificationEvent(
        id: j['id'] as String,
        sessionId: j['sessionId'] as String,
        type: NotificationType.values.byName(j['type'] as String),
        trigger: NotificationTrigger.values.byName(j['trigger'] as String),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

extension DeliveryStatusLabel on DeliveryStatus {
  String get label => switch (this) {
    DeliveryStatus.available => 'Available in app',
    DeliveryStatus.pending => 'Pending',
    DeliveryStatus.sent => 'Sent',
    DeliveryStatus.delivered => 'Delivered',
    DeliveryStatus.failed => 'Failed',
    DeliveryStatus.fallbackSent => 'Fallback Sent',
  };
}

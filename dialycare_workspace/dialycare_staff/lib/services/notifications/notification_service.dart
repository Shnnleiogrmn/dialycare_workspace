import '../../models/notification_delivery.dart';
import 'providers.dart';

typedef SaveAttempt = Future<void> Function(
  DeliveryAttempt attempt, {
  bool replacePending,
});

class NotificationService {
  const NotificationService({
    this.push = const UnconfiguredPushService(),
    this.sms = const UnconfiguredSmsService(),
    this.countryCallingCode,
  });
  final PushNotificationService push;
  final SmsService sms;
  final String? countryCallingCode;
  bool get configured => push.configured || sms.configured;
  String routeLabel(NotificationRecipient recipient) {
    if (recipient.registration.hasValidPush && push.configured) {
      return 'Push Notification';
    }
    if (smsDestination(
          recipient.phone,
          countryCallingCode: countryCallingCode,
        ) ==
        null) {
      return 'SMS Unavailable';
    }
    return sms.configured
        ? 'SMS Fallback'
        : 'SMS Fallback • provider not configured';
  }

  Future<void> deliver({
    required NotificationDelivery delivery,
    required NotificationRecipient recipient,
    required SaveAttempt save,
    required Future<void> Function() invalidate,
  }) async {
    Future<ProviderResult> attempt(
      DeliveryChannel channel, {
      bool fallback = false,
    }) async {
      final now = DateTime.now();
      await save(
        DeliveryAttempt(
          channel: channel,
          status: DeliveryStatus.pending,
          createdAt: now,
        ),
      );
      ProviderResult result;
      try {
        if (channel == DeliveryChannel.push) {
          result = await push
              .send(
                recipient: recipient,
                title: delivery.title,
                message: delivery.message,
                idempotencyKey: '${delivery.id}:push',
              )
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () => throw const DeliveryOutcomeUnknown(),
              );
        } else {
          final destination = smsDestination(
            recipient.phone,
            countryCallingCode: countryCallingCode,
          );
          result = destination == null
              ? const ProviderResult(
                  status: DeliveryStatus.failed,
                  reason: 'No valid international mobile number is registered.',
                )
              : await sms
                    .send(
                      recipient: recipient,
                      destination: destination,
                      message: delivery.message,
                      idempotencyKey: '${delivery.id}:sms',
                    )
                    .timeout(
                      const Duration(seconds: 30),
                      onTimeout: () => throw const DeliveryOutcomeUnknown(),
                    );
        }
      } on DeliveryOutcomeUnknown {
        result = const ProviderResult(
          status: DeliveryStatus.pending,
          reason:
              'Provider outcome unknown. Backend reconciliation is required.',
        );
      } catch (_) {
        result = const ProviderResult(
          status: DeliveryStatus.pending,
          reason: 'Provider response unavailable. Backend reconciliation is required.',
        );
      }
      final safeReason = recipient.registration.pushToken.isEmpty
          ? result.reason
          : result.reason.replaceAll(
              recipient.registration.pushToken,
              '[redacted]',
            );
      final accepted =
          result.status == DeliveryStatus.sent ||
          result.status == DeliveryStatus.delivered;
      // Only authoritative provider acceptance can be shown as Sent/Delivered.
      final status = fallback && result.status == DeliveryStatus.sent
          ? DeliveryStatus.fallbackSent
          : result.status;
      await save(
        DeliveryAttempt(
          channel: channel,
          status: status,
          createdAt: now,
          sentAt: accepted ? DateTime.now() : null,
          deliveredAt: result.status == DeliveryStatus.delivered
              ? DateTime.now()
              : null,
          providerId: result.providerId,
          reason: safeReason,
        ),
        replacePending: true,
      );
      return result;
    }

    if (recipient.registration.hasValidPush) {
      final result = await attempt(DeliveryChannel.push);
      if (result.invalidRegistration &&
          result.status == DeliveryStatus.failed) {
        await invalidate();
      }
      if (result.status == DeliveryStatus.failed) {
        await attempt(DeliveryChannel.sms, fallback: true);
      }
    } else {
      await attempt(DeliveryChannel.sms);
    }
  }
}

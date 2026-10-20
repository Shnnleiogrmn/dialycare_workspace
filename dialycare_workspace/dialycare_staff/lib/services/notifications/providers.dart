import 'package:core_shared/core_shared.dart';

import '../../models/notification_delivery.dart';
import '../../models/patient.dart';

class NotificationRecipient {
  const NotificationRecipient({
    required this.id,
    this.publicId = '',
    required this.patientId,
    required this.name,
    required this.phone,
    required this.type,
    required this.registration,
    this.mobileAccount = const MobileAccount(),
  });
  final String id, publicId, patientId, name, phone;
  String get displayId => publicId.isNotEmpty
      ? publicId
      : centerIdLabel(id, type == RecipientType.patient ? 'DC-' : 'R-');
  final RecipientType type;
  final AppRegistration registration;
  final MobileAccount mobileAccount;
}

class RecipientResolver {
  const RecipientResolver();
  List<NotificationRecipient> resolve(
    Patient patient, {
    bool includePatient = true,
    bool includeRelatives = true,
  }) => [
    if (includePatient && patient.registration.notificationsEnabled)
      NotificationRecipient(
        id: patient.id,
        publicId: patient.displayId,
        patientId: patient.id,
        name: patient.name,
        phone: patient.contact,
        type: RecipientType.patient,
        registration: patient.registration,
        mobileAccount: patient.mobileAccount,
      ),
    if (includeRelatives)
      for (final relative in patient.companions)
        if (relative.registration.notificationsEnabled)
          NotificationRecipient(
            id: relative.id,
            publicId: relative.displayId,
            patientId: patient.id,
            name: relative.name,
            phone: relative.contact,
            type: RecipientType.relative,
            registration: relative.registration,
            mobileAccount: relative.mobileAccount,
          ),
  ];
}

// Only an authenticated backend adapter may produce these verified registrations.
// There is deliberately no staff UI toggle for app connection or token entry.
class VerifiedDeviceRegistration {
  const VerifiedDeviceRegistration({
    required this.patientId,
    required this.recipientId,
    required this.type,
    required this.registration,
  });
  final String patientId, recipientId;
  final RecipientType type;
  final AppRegistration registration;
}

abstract interface class RegistrationSource {
  Future<List<VerifiedDeviceRegistration>> fetchRegistrations();
}

class DeliveryRules {
  const DeliveryRules({
    this.notifyPatient = true,
    this.notifyRelatives = true,
    this.reminderLead = const Duration(hours: 24),
    this.endingSoonLead = const Duration(minutes: 10),
  });
  final bool notifyPatient, notifyRelatives;
  final Duration reminderLead, endingSoonLead;
}

// E.164 destinations only unless a deployment explicitly supplies a country code.
String? smsDestination(String phone, {String? countryCallingCode}) {
  var number = phone.trim().replaceAll(RegExp(r'[\s()\-]'), '');
  if (!number.startsWith('+') &&
      countryCallingCode != null &&
      RegExp(r'^0[0-9]+$').hasMatch(number)) {
    number = '$countryCallingCode${number.substring(1)}';
  }
  return RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(number) ? number : null;
}

class ProviderResult {
  const ProviderResult({
    required this.status,
    this.providerId = '',
    this.reason = '',
    this.invalidRegistration = false,
  });
  final DeliveryStatus status;
  final String providerId, reason;
  final bool invalidRegistration;
}

abstract interface class PushNotificationService {
  bool get configured;
  Future<ProviderResult> send({
    required NotificationRecipient recipient,
    required String title,
    required String message,
    required String idempotencyKey,
  });
}

abstract interface class SmsService {
  bool get configured;
  Future<ProviderResult> send({
    required NotificationRecipient recipient,
    required String destination,
    required String message,
    required String idempotencyKey,
  });
}

class UnconfiguredPushService implements PushNotificationService {
  const UnconfiguredPushService();
  @override
  bool get configured => false;
  @override
  Future<ProviderResult> send({
    required NotificationRecipient recipient,
    required String title,
    required String message,
    required String idempotencyKey,
  }) async => const ProviderResult(
    status: DeliveryStatus.failed,
    reason: 'Push backend is not configured.',
  );
}

class UnconfiguredSmsService implements SmsService {
  const UnconfiguredSmsService();
  @override
  bool get configured => false;
  @override
  Future<ProviderResult> send({
    required NotificationRecipient recipient,
    required String destination,
    required String message,
    required String idempotencyKey,
  }) async => const ProviderResult(
    status: DeliveryStatus.failed,
    reason: 'SMS backend is not configured.',
  );
}

// A transport timeout has an unknown acceptance outcome. Do not silently retry or
// fall back: the server must reconcile this idempotency key with the provider.
class DeliveryOutcomeUnknown implements Exception {
  const DeliveryOutcomeUnknown();
}

import 'package:flutter_test/flutter_test.dart';
import 'package:dialycare_staff/models/patient.dart';
import 'package:dialycare_staff/models/session.dart';
import 'package:dialycare_staff/models/notification_delivery.dart';
import 'package:dialycare_staff/services/staff_store.dart';
import 'package:dialycare_staff/services/notifications/providers.dart';
import 'package:dialycare_staff/services/notifications/notification_service.dart';

class TestPush implements PushNotificationService {
  final calls = <String>[];
  ProviderResult result = const ProviderResult(
    status: DeliveryStatus.sent,
    providerId: 'test-push',
  );
  bool unknown = false;
  @override
  bool get configured => true;
  @override
  Future<ProviderResult> send({
    required NotificationRecipient recipient,
    required String title,
    required String message,
    required String idempotencyKey,
  }) async {
    calls.add(recipient.id);
    if (unknown) throw const DeliveryOutcomeUnknown();
    return result;
  }
}

class TestSms implements SmsService {
  final calls = <String>[];
  ProviderResult result = const ProviderResult(
    status: DeliveryStatus.sent,
    providerId: 'test-sms',
  );
  @override
  bool get configured => true;
  @override
  Future<ProviderResult> send({
    required NotificationRecipient recipient,
    required String destination,
    required String message,
    required String idempotencyKey,
  }) async {
    calls.add(recipient.id);
    return result;
  }
}

class TestRegistrations implements RegistrationSource {
  TestRegistrations(this.records);
  final List<VerifiedDeviceRegistration> records;
  @override
  Future<List<VerifiedDeviceRegistration>> fetchRegistrations() async =>
      records;
}

AppRegistration registered(bool connected) => AppRegistration(
  status: connected
      ? AppRegistrationStatus.connected
      : AppRegistrationStatus.notRegistered,
  pushToken: connected ? 'test-device-token' : '',
  backendVerified: true,
);
StaffStore fixture(
  TestPush push,
  TestSms sms, {
  bool patientConnected = false,
  bool relativeConnected = false,
  String phone = '+639171234567',
  bool relative = true,
}) {
  final store = StaffStore(
    memoryOnly: true,
    deliveryService: NotificationService(push: push, sms: sms),
  );
  store.patients = [
    Patient(
      id: 'DC-X',
      name: 'Example Patient',
      age: 40,
      gender: 'Female',
      contact: phone,
      registration: registered(patientConnected),
      companions: relative
          ? [
              Companion(
                id: 'R-X',
                name: 'Example Relative',
                relationship: 'Son',
                contact: '+639181234567',
                registration: registered(relativeConnected),
              ),
            ]
          : [],
    ),
  ];
  store.sessions = [
    SessionRecord(
      plannedDurationMinutes: 240,
      id: 'S-X',
      patientId: 'DC-X',
      start: DateTime(2026, 10, 15, 8),
      room: 'Room 12',
      batch: 'Batch C',
      status: SessionStatus.pending,
    ),
  ];
  store.notifications = [];
  return store;
}

void main() {
  for (final pc in [false, true]) {
    for (final rc in [false, true]) {
      test('independent routes patient=$pc relative=$rc', () async {
        final push = TestPush(), sms = TestSms();
        final store = fixture(
          push,
          sms,
          patientConnected: pc,
          relativeConnected: rc,
        );
        final results = await store.sendReminder(
          'S-X',
          recipientIds: {'DC-X', 'R-X'},
        );
        expect(push.calls.toSet(), {if (pc) 'DC-X', if (rc) 'R-X'});
        expect(sms.calls.toSet(), {if (!pc) 'DC-X', if (!rc) 'R-X'});
        expect(results.every((d) => d.status == DeliveryStatus.sent), isTrue);
        expect(
          results.every((d) => d.trigger == NotificationTrigger.staff),
          isTrue,
        );
        store.dispose();
      });
    }
  }
  test('invalid push token falls back and is not reused', () async {
    final push = TestPush()
      ..result = const ProviderResult(
        status: DeliveryStatus.failed,
        invalidRegistration: true,
        reason: 'Unregistered device',
      );
    final sms = TestSms();
    final store = fixture(push, sms, patientConnected: true, relative: false);
    var results = await store.sendReminder('S-X', recipientIds: {'DC-X'});
    expect(results.single.status, DeliveryStatus.fallbackSent);
    expect(results.single.attempts.length, 2);
    expect(
      store.patients.single.registration.status,
      AppRegistrationStatus.unavailable,
    );
    expect(store.patients.single.registration.pushToken, isEmpty);
    results = await store.sendReminder('S-X', recipientIds: {'DC-X'});
    expect(push.calls.length, 1);
    expect(results.single.attempts.single.channel, DeliveryChannel.sms);
    store.dispose();
  });
  test('push failure with missing phone records failed SMS', () async {
    final push = TestPush()
      ..result = const ProviderResult(
        status: DeliveryStatus.failed,
        reason: 'Rejected',
      );
    final sms = TestSms();
    final store = fixture(
      push,
      sms,
      patientConnected: true,
      phone: '',
      relative: false,
    );
    final result = (await store.sendReminder(
      'S-X',
      recipientIds: {'DC-X'},
    )).single;
    expect(result.status, DeliveryStatus.failed);
    expect(result.attempts.length, 2);
    expect(sms.calls, isEmpty);
    expect(result.attempts.last.reason, contains('valid international'));
    store.dispose();
  });
  test(
    'unknown provider acceptance stays pending without duplicate SMS',
    () async {
      final push = TestPush()..unknown = true;
      final sms = TestSms();
      final store = fixture(push, sms, patientConnected: true, relative: false);
      final result = (await store.sendReminder(
        'S-X',
        recipientIds: {'DC-X'},
      )).single;
      expect(result.status, DeliveryStatus.pending);
      expect(sms.calls, isEmpty);
      expect(result.attempts.single.sentAt, isNull);
      store.dispose();
    },
  );
  test('unconfigured providers never report sent', () async {
    final store = StaffStore(memoryOnly: true);
    final result = await store.sendReminder(
      store.sessions.first.id,
      recipientIds: {store.patients.first.id},
    );
    expect(result.single.status, DeliveryStatus.failed);
    expect(result.single.attempts.single.sentAt, isNull);
    store.dispose();
  });
  test('status transitions and scheduled events are deduplicated', () async {
    final push = TestPush(), sms = TestSms();
    final store = fixture(push, sms);
    await Future.wait([
      store.changeSessionStatus(
        'S-X',
        SessionStatus.inProgress,
        expectedEnd: DateTime(2026, 10, 15, 12),
      ),
      store.changeSessionStatus('S-X', SessionStatus.inProgress),
    ]);
    expect(store.notificationEvents.length, 1);
    expect(store.deliveryHistory.length, 2);
    final estimated = store.sessions.single.estimatedEnd!;
    await store.processDueNotifications(
      estimated.subtract(const Duration(minutes: 10)),
    );
    await store.processDueNotifications(
      estimated.subtract(const Duration(minutes: 9)),
    );
    expect(
      store.notificationEvents
          .where((e) => e.type == NotificationType.endingSoon)
          .length,
      1,
    );
    await store.changeSessionStatus('S-X', SessionStatus.completed);
    await store.changeSessionStatus('S-X', SessionStatus.readyForPickUp);
    await store.changeSessionStatus('S-X', SessionStatus.readyForPickUp);
    expect(
      store.notificationEvents
          .where((e) => e.type == NotificationType.pickup)
          .length,
      1,
    );
    final pickup = store.deliveryHistory
        .where((d) => d.type == NotificationType.pickup)
        .toList();
    expect(
      pickup
          .singleWhere((d) => d.recipientType == RecipientType.relative)
          .message,
      contains('Example Patient is ready for pickup'),
    );
    expect(pickup.every((d) => d.message.contains('Room 12')), isTrue);
    store.dispose();
  });
  test('reminders and schedule changes use actual data', () async {
    final push = TestPush(), sms = TestSms();
    final store = fixture(push, sms);
    await store.processDueNotifications(DateTime(2026, 10, 14, 9));
    await store.processDueNotifications(DateTime(2026, 10, 14, 10));
    expect(store.notificationEvents.length, 1);
    expect(store.deliveryHistory.first.message, contains('Oct 15, 2026'));
    expect(store.deliveryHistory.first.message, contains('Batch C'));
    await store.updateSchedule(
      'S-X',
      start: DateTime(2026, 10, 16, 9),
      room: 'Room 14',
      batch: 'Batch B',
    );
    expect(
      store.notificationEvents.last.type,
      NotificationType.scheduleRescheduled,
    );
    expect(store.deliveryHistory.first.message, contains('Oct 16, 2026'));
    expect(store.deliveryHistory.first.message, contains('Room 14'));
    await store.updateSchedule(
      'S-X',
      start: DateTime(2026, 10, 16, 9),
      room: 'Room 14',
      batch: 'Batch A',
    );
    expect(
      store.notificationEvents.last.type,
      NotificationType.scheduleUpdated,
    );
    await store.changeSessionStatus(
      'S-X',
      SessionStatus.cancelled,
      reasonCode: 'transfer',
    );
    expect(
      store.notificationEvents.last.type,
      NotificationType.scheduleCancelled,
    );
    store.dispose();
  });
  test(
    'legacy model migration and authoritative registration import',
    () async {
      final push = TestPush(), sms = TestSms();
      final store = fixture(push, sms);
      final p = store.patients.single;
      final legacy = Patient.fromJson({...p.toJson()}..remove('registration'));
      expect(legacy.registration.backendVerified, isFalse);
      await store.syncRegistrations(
        TestRegistrations([
          VerifiedDeviceRegistration(
            patientId: p.id,
            recipientId: 'R-X',
            type: RecipientType.relative,
            registration: registered(true),
          ),
        ]),
      );
      expect(store.patients.single.registration.hasValidPush, isFalse);
      expect(
        store.patients.single.companions.single.registration.hasValidPush,
        isTrue,
      );
      await expectLater(
        store.syncRegistrations(
          TestRegistrations([
            VerifiedDeviceRegistration(
              patientId: p.id,
              recipientId: p.id,
              type: RecipientType.patient,
              registration: const AppRegistration(
                status: AppRegistrationStatus.connected,
                pushToken: 'unverified',
              ),
            ),
          ]),
        ),
        throwsStateError,
      );
      store.dispose();
    },
  );
  test(
    'history survives reload and automatic event keys survive restart',
    () async {
      String? saved;
      final push = TestPush(), sms = TestSms();
      final initial = fixture(push, sms);
      final store = StaffStore(
        readData: () async => saved,
        writeData: (data) async {
          saved = data;
        },
        deliveryService: NotificationService(push: push, sms: sms),
      );
      store.patients = initial.patients;
      store.sessions = initial.sessions;
      store.notifications = [];
      await store.processDueNotifications(DateTime(2026, 10, 14, 9));
      final loaded = StaffStore(
        readData: () async => saved,
        writeData: (data) async {
          saved = data;
        },
        deliveryService: NotificationService(push: push, sms: sms),
      );
      await loaded.load();
      await loaded.processDueNotifications(DateTime(2026, 10, 14, 10));
      expect(loaded.notificationEvents.length, 1);
      expect(loaded.deliveryHistory.length, 2);
      expect(sms.calls.length, 2);
      initial.dispose();
      store.dispose();
      loaded.dispose();
    },
  );
  test('no acceptance is attempted before durable event persistence', () async {
    final push = TestPush(), sms = TestSms();
    final initial = fixture(push, sms);
    final store = StaffStore(
      writeData: (_) async => throw StateError('disk full'),
      deliveryService: NotificationService(push: push, sms: sms),
    );
    store.patients = initial.patients;
    store.sessions = initial.sessions;
    await expectLater(
      store.changeSessionStatus('S-X', SessionStatus.inProgress),
      throwsStateError,
    );
    expect(store.sessions.single.status, SessionStatus.pending);
    expect(store.notificationEvents, isEmpty);
    expect(push.calls, isEmpty);
    expect(sms.calls, isEmpty);
    store.dispose();
    initial.dispose();
  });
}

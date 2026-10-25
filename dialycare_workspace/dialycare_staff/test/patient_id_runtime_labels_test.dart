import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dialycare_staff/main.dart';
import 'package:dialycare_staff/models/patient.dart';
import 'package:dialycare_staff/models/notification_delivery.dart';
import 'package:dialycare_staff/services/staff_store.dart';

void main() {
  testWidgets(
    'Dashboard and retained notifications resolve current public IDs',
    (tester) async {
      final day = DateTime(2026, 10, 14, 9);
      final store = StaffStore(memoryOnly: true, now: day);
      final pid = store.sessions.first.patientId;
      store.patients = [
        for (final p in store.patients)
          if (p.id == pid)
            Patient.fromJson({...p.toJson(), 'publicId': 'DP-2026-001'})
          else
            p,
      ];
      store.notifications = [];
      store.deliveryHistory = [
        NotificationDelivery(
          id: 'synthetic-notice',
          eventId: 'synthetic-event',
          patientId: pid,
          recipientId: pid,
          recipientType: RecipientType.patient,
          recipientName: 'Synthetic recipient',
          type: NotificationType.concernUpdate,
          title: 'Synthetic update',
          message: 'Original notice retained.',
          trigger: NotificationTrigger.automatic,
          sessionId: '',
          createdAt: day,
        ),
      ];
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(store.dispose);
      await tester.pumpWidget(DialyCareApp(store: store, now: day));
      await tester.pumpAndSettle();
      expect(find.textContaining('DP-2026-001'), findsWidgets);
      await tester.tap(find.text('Notification'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Patient ID: DP-2026-001'), findsOneWidget);
      expect(find.textContaining('Original notice retained.'), findsOneWidget);
      expect(store.deliveryHistory.single.patientId, pid);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

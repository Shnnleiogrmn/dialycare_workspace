import 'package:core_shared/core_shared.dart';
import 'package:dialycare_staff/screens/dashboard/dashboard_screen.dart';
import 'package:dialycare_staff/screens/schedules/schedules_screen.dart';
import 'package:dialycare_staff/screens/sessions/sessions_screen.dart';
import 'package:dialycare_staff/services/staff_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'removed labels leave working schedule entry points and next-date sessions',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final today = DateTime(2026, 10, 22, 12);
      final store = StaffStore(memoryOnly: true, now: today);
      addTearDown(store.dispose);
      SessionRecord session(String id, int day, SessionStatus status) =>
          SessionRecord(
            id: id,
            patientId: store.patients.first.id,
            start: DateTime(2026, 10, day, 9),
            room: 'Test room',
            batch: 'Batch A',
            status: status,
          );
      store.sessions = [
        session('ongoing', 22, SessionStatus.inProgress),
        session('pending', 22, SessionStatus.pending),
        session('future', 24, SessionStatus.pending),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardScreen(store: store, now: today),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining("Today's Group"), findsNothing);
      expect(find.text('No regular group today'), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SchedulesScreen(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      // Only the functional toolbar action remains, not a duplicate tab/header.
      expect(find.text('Schedule'), findsNothing);
      expect(find.text('+ Add Schedule'), findsOneWidget);
      await tester.tap(find.text('+ Add Schedule'));
      await tester.pumpAndSettle();
      expect(find.text('Back to schedules'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.text('Add'), findsWidgets);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionsScreen(store: store, day: today),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ongoing (1)'), findsOneWidget);
      expect(find.byKey(const ValueKey('manage-ongoing')), findsOneWidget);
      expect(find.byKey(const ValueKey('manage-pending')), findsOneWidget);
      await tester.tap(find.text('Upcoming (1)'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('manage-future')), findsOneWidget);
      expect(find.byKey(const ValueKey('manage-pending')), findsNothing);
      expect(find.byKey(const ValueKey('upcoming-date')), findsOneWidget);
      store.sessions.removeWhere((s) => s.id == 'future');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionsScreen(
              key: const ValueKey('empty'),
              store: store,
              day: today,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upcoming (0)'));
      await tester.pumpAndSettle();
      expect(find.text('No upcoming sessions scheduled.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

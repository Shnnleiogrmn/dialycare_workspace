import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dialycare_staff/screens/staff_portal.dart';
import 'package:dialycare_staff/services/staff_store.dart';

void main() {
  testWidgets(
    'Reports header opens read-only History and Back restores Reports',
    (tester) async {
      final store = StaffStore(
        memoryOnly: true,
        history: CallbackHistoryService(
          () async => [
            const HistoryItem(
              category: 'Sessions',
              title: 'Completed',
              patient: 'Synthetic • DP-2026-001',
              timestamp: '2026-10-21T08:00:00Z',
              details: 'Batch A',
            ),
            const HistoryItem(
              category: 'Feedback & Concerns',
              title: 'Closed concern',
              patient: 'Synthetic • DP-2026-001',
              timestamp: '2026-10-22T08:00:00Z',
              details: 'Historical concern',
              status: 'Closed',
            ),
          ],
        ),
      );
      addTearDown(store.dispose);
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: StaffPortal(store: store, now: DateTime(2026, 10, 24)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      expect(find.text('Total Sessions'), findsOneWidget);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsNothing);
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Closed concern'), findsOneWidget);
      expect(find.text('Closed'), findsOneWidget);
      expect(find.textContaining('DP-2026-001'), findsWidgets);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sessions').last);
      await tester.pumpAndSettle();
      expect(find.text('Closed concern'), findsNothing);
      expect(find.text('Completed'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Total Sessions'), findsOneWidget);
      expect(find.text('Feedback & Concerns'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}

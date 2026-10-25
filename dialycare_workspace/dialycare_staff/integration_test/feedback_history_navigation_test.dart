import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:dialycare_staff/main.dart';
import 'package:dialycare_staff/services/staff_store.dart';

import '../../core_shared/test/helpers/concern_fake.dart';

// Device runtime navigation with fictional authenticated data, not live login.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('production Staff app opens Feedback and Reports History', (
    tester,
  ) async {
    final store = StaffStore(
      memoryOnly: true,
      concerns: ConcernFake(),
      history: CallbackHistoryService(() async => []),
    );
    await tester.pumpWidget(DialyCareApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feedback & Concerns'));
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackConcernsPage), findsOneWidget);
    expect(find.text('Submitted: 0'), findsOneWidget);
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityHistoryPage), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
    await tester.tap(find.text('Date'));
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('compact-range-panel'));
    expect(tester.getSize(panel).width, lessThanOrEqualTo(370));
    expect(tester.getSize(panel).height, lessThan(600));
    final today = DateTime.now();
    final day = find.byKey(
      ValueKey('range-day-${today.year}-${today.month}-${today.day}'),
    );
    await tester.tap(day);
    await tester.pumpAndSettle();
    await tester.tap(day);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Clear dates'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Total Sessions'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}

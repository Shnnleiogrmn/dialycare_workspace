import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_shared/core_shared.dart';
import 'package:core_shared/compact_date_range_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'History applies inclusive dates, preserves Cancel and clears the range',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final today = DateUtils.dateOnly(DateTime.now());
      HistoryItem item(String title, DateTime time) => HistoryItem(
        category: 'Sessions',
        title: title,
        patient: 'Synthetic Patient',
        timestamp: time.toUtc().toIso8601String(),
        details: 'Read only',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityHistoryPage(
              service: CallbackHistoryService(
                () async => [
                  item('Start boundary', today),
                  item(
                    'End boundary',
                    today.add(const Duration(hours: 23, minutes: 59)),
                  ),
                  item('Outside range', today.add(const Duration(days: 1))),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      final day = find.byKey(
        ValueKey('range-day-${today.year}-${today.month}-${today.day}'),
      );
      await tester.tap(day);
      await tester.pumpAndSettle();
      await tester.tap(day);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Date'), findsOneWidget);
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      await tester.tap(day);
      await tester.pumpAndSettle();
      await tester.tap(day);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(
        find.text('${historyRangeDate(today)} – ${historyRangeDate(today)}'),
        findsOneWidget,
      );
      expect(find.text('Start boundary'), findsOneWidget);
      expect(find.text('End boundary'), findsOneWidget);
      expect(find.text('Outside range'), findsNothing);
      await tester.tap(find.text('Clear dates'));
      await tester.pumpAndSettle();
      expect(find.text('Outside range'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 390.0, 1200.0]) {
    testWidgets('History cards, filters, model labels and details fit $width', (
      tester,
    ) async {
      final font = File('C:/Windows/Fonts/arial.ttf');
      if (font.existsSync()) {
        await (FontLoader('HistoryQA')..addFont(
              Future.value(ByteData.sublistView(font.readAsBytesSync())),
            ))
            .load();
      }
      final icons = File(
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (icons.existsSync()) {
        await (FontLoader('MaterialIcons')..addFont(
              Future.value(ByteData.sublistView(icons.readAsBytesSync())),
            ))
            .load();
      }
      var publicId = 'DC-000002';
      var back = false;
      final service = CallbackHistoryService(
        () async => [
          HistoryItem(
            category: 'Feedback & Concerns',
            title: 'Schedule update question',
            patient: 'Synthetic Patient • $publicId',
            timestamp: '2026-10-23T08:00:00Z',
            details: 'Original concern and response remain available.',
            status: 'Closed',
          ),
          HistoryItem(
            category: 'Sessions',
            title: 'Completed',
            patient: 'Synthetic Patient • $publicId',
            timestamp: '2026-10-22T08:00:00Z',
            details: 'Active duration: 210 minutes',
            status: 'Completed',
          ),
        ],
      );
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: 'HistoryQA',
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff0b3764),
              ),
            ),
            home: Scaffold(
              body: ActivityHistoryPage(
                service: service,
                staff: width >= 760,
                onBack: width >= 760 ? () => back = true : null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsNothing);
      expect(find.text('Closed'), findsOneWidget);
      expect(find.textContaining('DC-000002'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/verification/history-${width.toInt()}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      publicId = 'DP-2026-002'; // Changed repository label, not a UI formatter.
      await tester.tap(find.byTooltip('Refresh history'));
      await tester.pumpAndSettle();
      expect(find.textContaining('DP-2026-002'), findsWidgets);
      expect(find.textContaining('DC-000002'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Search history'),
        'no matches',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No historical records match these filters.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Search history'),
        '',
      );
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sessions').last);
      await tester.pumpAndSettle();
      expect(find.text('Schedule update question'), findsNothing);
      await tester.ensureVisible(find.text('Completed'));
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      expect(find.textContaining('210 minutes'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      if (width >= 760) {
        await tester.tap(find.text('Back'));
        expect(back, isTrue);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

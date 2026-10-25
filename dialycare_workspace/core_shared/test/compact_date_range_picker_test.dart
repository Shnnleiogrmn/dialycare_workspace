import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_shared/compact_date_range_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 390.0, 1200.0]) {
    testWidgets(
      'compact range selection, cancellation and month boundaries at $width',
      (tester) async {
        final font = File('C:/Windows/Fonts/arial.ttf');
        if (font.existsSync()) {
          await (FontLoader('CalendarQA')..addFont(
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
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var selected = DateTimeRange(
          start: DateTime(2026, 10, 1),
          end: DateTime(2026, 10, 24),
        );
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                fontFamily: 'CalendarQA',
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xff0b3764),
                ),
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      final next = await showCompactDateRangePicker(
                        context: context,
                        initialDateRange: selected,
                        firstDate: DateTime(2026, 9, 1),
                        lastDate: DateTime(2026, 11, 30),
                      );
                      if (next != null) selected = next;
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        Future<void> tap(String key) async {
          await tester.tap(find.byKey(ValueKey(key)));
          await tester.pumpAndSettle();
        }

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final dialogSize = tester.getSize(
          find.byKey(const ValueKey('compact-range-panel')),
        );
        expect(dialogSize.width, lessThanOrEqualTo(370));
        expect(dialogSize.height, lessThan(600));
        await tap('range-day-2026-10-20');
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
              .onPressed,
          isNull,
        );
        await tap('range-day-2026-10-5'); // Backwards selection normalizes.
        expect(find.text('From: Oct 5, 2026'), findsOneWidget);
        expect(find.text('To: Oct 20, 2026'), findsOneWidget);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File(
            'build/verification/calendar-${width.toInt()}.png',
          );
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(selected.start, DateTime(2026, 10, 1));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tap('range-day-2026-10-31');
        await tester.tap(find.byTooltip('Next month'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton && widget.tooltip == 'Next month',
                ),
              )
              .onPressed,
          isNull,
        );
        await tap('range-day-2026-11-2');
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(selected.start, DateTime(2026, 10, 31));
        expect(selected.end, DateTime(2026, 11, 2));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('To: Nov 2, 2026'), findsOneWidget);
        await tap('range-day-2026-10-8');
        await tap('range-day-2026-10-8');
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(selected.duration, Duration.zero);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/notification_ui_flow.dart';

void main() {
  for (final size in [const Size(1400, 1000), const Size(900, 600)]) {
    testWidgets('notification composer and automatic events at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await notificationUiFlow(tester);
    });
  }
}

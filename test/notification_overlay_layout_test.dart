import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/app_navigator.dart' as navigation;
import 'package:life_pilot/utils/service/service_notification/notification_overlay.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(800, 300)]) {
    testWidgets('reminder text avoids its icon at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigation.navigatorKey,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: const Scaffold(body: Text('Calendar')),
        ),
      );
      const title = '行程提醒 Reminder';
      final body = List.filled(20, '提醒內容應換行而不是被圖示遮住。').join();
      showWebOverlay(title: title, body: body, tooltip: 'Close reminder');
      await tester.pump();
      expect(tester.takeException(), null);
      final iconRect = tester.getRect(find.byType(IconButton));
      expect(
        tester.getRect(find.text(title)).center.dy,
        closeTo(iconRect.center.dy, 0.1),
      );
      expect(
        tester.getRect(find.text(title)).left,
        greaterThan(iconRect.right),
      );
      expect(tester.getRect(find.text(body)).left, greaterThan(iconRect.right));
      expect(iconRect.right, lessThanOrEqualTo(size.width));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -100),
      );
      await tester.pump();
      expect(tester.takeException(), null);
      await tester.tap(find.byTooltip('Close reminder'));
      await tester.pump();
      expect(find.text(title), findsNothing);
      // Drain the existing auto-dismiss timer and verify a closed entry is safe.
      await tester.pump(const Duration(seconds: 11));
      expect(tester.takeException(), null);
      cancelWebReminders();
      await tester.pumpWidget(const SizedBox());
    });
  }
}

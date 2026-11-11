import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/widgets_event_image.dart';

void main() {
  testWidgets('memory image preserves its original aspect ratio', (
    tester,
  ) async {
    Future<bool> preservesFor(double cardWidth) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: cardWidth,
              child: const WidgetsEventImage(
                value:
                    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB'
                    'CAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
                preserveAspectRatio: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester
          .widget<WidgetsEventImage>(find.byType(WidgetsEventImage))
          .preserveAspectRatio;
    }

    expect(await preservesFor(300), isTrue);
    expect(await preservesFor(400), isTrue);
  });
}

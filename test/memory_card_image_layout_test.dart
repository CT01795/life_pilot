import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/widgets_event_image.dart';

void main() {
  testWidgets('memory image preserves its original aspect ratio', (
    tester,
  ) async {
    Future<void> expectUnconstrainedHeight(double cardWidth) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: cardWidth,
              child: const WidgetsEventImage(
                value: 'image-data',
                preserveAspectRatio: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WidgetsEventImage>(find.byType(WidgetsEventImage))
            .preserveAspectRatio,
        isTrue,
      );
      final outerImageBox = tester
          .widgetList<SizedBox>(
            find.descendant(
              of: find.byType(WidgetsEventImage),
              matching: find.byType(SizedBox),
            ),
          )
          .firstWhere((box) => box.width == double.infinity);
      expect(outerImageBox.height, isNull);
    }

    await expectUnconstrainedHeight(300);
    await expectUnconstrainedHeight(400);
  });

  test('event and calendar cards preserve uploaded image proportions', () {
    final eventCard = File(
      'lib/event/widgets_event_card.dart',
    ).readAsStringSync();
    final calendarCard = File(
      'lib/calendar/widgets_calendar_card.dart',
    ).readAsStringSync();

    expect(
      eventCard,
      contains(
        'value: widget.eventViewModel.masterGraphUrl,\n'
        '            preserveAspectRatio: true,',
      ),
    );
    expect(
      calendarCard,
      contains(
        'value: eventViewModel.masterGraphUrl,\n'
        '            preserveAspectRatio: true,',
      ),
    );
  });

  test('event and memory editors preserve uploaded image proportions', () {
    final eventEditor = File(
      'lib/event/page_event_add.dart',
    ).readAsStringSync();
    final memoryEditor = File(
      'lib/memory_trace/page_memory_add.dart',
    ).readAsStringSync();

    expect(eventEditor, contains('preserveAspectRatio: true,'));
    expect(memoryEditor, contains('preserveAspectRatio: true,'));
  });
}

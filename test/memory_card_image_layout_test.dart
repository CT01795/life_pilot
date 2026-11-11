import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/widgets_event_image.dart';

void main() {
  testWidgets('memory image preserves its original aspect ratio', (
    tester,
  ) async {
    Future<void> expectResponsiveHeight({
      required double cardWidth,
      required double viewportHeight,
      required double expectedMaxHeight,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(cardWidth, viewportHeight)),
            child: Center(
              child: SizedBox(
                width: cardWidth,
                child: const WidgetsEventImage(
                  value: 'image-data',
                  preserveAspectRatio: true,
                ),
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
      final imageConstraint = tester
          .widgetList<ConstrainedBox>(
            find.descendant(
              of: find.byType(WidgetsEventImage),
              matching: find.byType(ConstrainedBox),
            ),
          )
          .firstWhere((box) => box.constraints.maxHeight == expectedMaxHeight);
      expect(imageConstraint.constraints.maxHeight, expectedMaxHeight);
    }

    await expectResponsiveHeight(
      cardWidth: 300,
      viewportHeight: 600,
      expectedMaxHeight: 300,
    );
    await expectResponsiveHeight(
      cardWidth: 400,
      viewportHeight: 1000,
      expectedMaxHeight: 500,
    );
  });

  testWidgets('original-ratio images use contain instead of cropping', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WidgetsEventImage(
          value: 'https://example.com/image.jpg',
          preserveAspectRatio: true,
        ),
      ),
    );

    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
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

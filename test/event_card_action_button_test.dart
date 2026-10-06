import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/widgets_event_utils.dart';

void main() {
  testWidgets('card action buttons share one accessible size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              EventCardActionButton(
                icon: Icons.delete,
                tooltip: 'Delete',
                onPressed: () {},
              ),
              const SizedBox(width: eventCardActionSpacing),
              PressButton(
                isPress: false,
                color: Colors.pinkAccent,
                onPressed: () async {},
                pressedIcon: Icons.favorite,
                unPressedIcon: Icons.favorite_border,
                tooltip: 'Like',
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(EventCardActionButton)),
      const Size.square(eventCardActionButtonSize),
    );
    expect(
      tester.getSize(find.byType(PressButton)),
      const Size.square(eventCardActionButtonSize),
    );

    for (final button in tester.widgetList<IconButton>(
      find.byType(IconButton),
    )) {
      expect(button.iconSize, eventCardActionIconSize);
    }
    expect(tester.takeException(), isNull);
  });
}

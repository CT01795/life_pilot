import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final captured in [false, true]) {
    testWidgets(
      'background tap dismisses keyboard without hit-test warnings, captured=$captured',
      (tester) async {
        final previous = WidgetController.hitTestWarningShouldBeFatal;
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(
          () => WidgetController.hitTestWarningShouldBeFatal = previous,
        );
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KeyboardDismissOnTap(
                dismissOnCapturedTaps: captured,
                child: Column(
                  children: [
                    const SizedBox(
                      key: ValueKey('background'),
                      width: 100,
                      height: 100,
                      // A plain SizedBox has layout size but no hit-testable content.
                      child: ColoredBox(color: Colors.transparent),
                    ),
                    TextField(focusNode: focus),
                  ],
                ),
              ),
            ),
          ),
        );
        focus.requestFocus();
        await tester.pump();
        expect(focus.hasFocus, true);
        await tester.tap(find.byKey(const ValueKey('background')));
        await tester.pump();
        expect(focus.hasFocus, false);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('tapping the editable field still focuses it', (tester) async {
    final previous = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = previous);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardDismissOnTap(child: TextField(focusNode: focus)),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focus.hasFocus, true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

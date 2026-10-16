import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/widgets_scratch_workspace.dart';

void main() {
  for (final width in [320.0, 599.0, 600.0, 800.0, 1920.0]) {
    test('Web and native layout ratios at width $width', () {
      expect(
        ScratchWorkspace.editorFlexFor(width: width, web: true),
        width < 600 ? 1 : 2,
      );
      expect(ScratchWorkspace.editorFlexFor(width: width, web: false), 1);
    });
  }
  testWidgets('rotation preserves the editor state', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScratchWorkspace(
            editor: StatefulBuilder(
              builder: (context, setState) =>
                  const ColoredBox(color: Colors.blue),
            ),
            board: const ColoredBox(color: Colors.green),
          ),
        ),
      ),
    );
    final before = tester.state(find.byType(StatefulBuilder));
    tester.view.physicalSize = const Size(740, 360);
    await tester.pump();
    expect(identical(before, tester.state(find.byType(StatefulBuilder))), true);
    expect(tester.takeException(), null);
  });
  for (final size in [
    const Size(360, 740),
    const Size(800, 360),
    const Size(1024, 768),
  ]) {
    testWidgets(
      'editor and board fit at $size without competing scroll views',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const editorKey = ValueKey('editor');
        const boardKey = ValueKey('board');
        var drags = 0;
        var starts = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ScratchWorkspace(
                editor: Column(
                  key: editorKey,
                  children: [
                    TextButton(
                      onPressed: () => starts++,
                      child: const Text('Start'),
                    ),
                    Expanded(
                      child: RawGestureDetector(
                        gestures: {
                          EagerGestureRecognizer:
                              GestureRecognizerFactoryWithHandlers<
                                EagerGestureRecognizer
                              >(EagerGestureRecognizer.new, (_) {}),
                        },
                        child: Listener(
                          onPointerMove: (_) => drags++,
                          child: const ColoredBox(
                            color: Colors.blue,
                            child: SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                board: const ColoredBox(key: boardKey, color: Colors.green),
              ),
            ),
          ),
        );
        final editor = tester.getRect(find.byKey(editorKey));
        final board = tester.getRect(find.byKey(boardKey));
        expect(editor.overlaps(board), false);
        for (final rect in [editor, board]) {
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
        }
        expect(find.byType(Scrollable), findsNothing);
        if (size.width < 600) {
          expect(board.top, greaterThan(editor.bottom));
          expect(editor.height, closeTo(board.height, 0.1));
        } else {
          expect(board.left, greaterThan(editor.right));
          expect(editor.width, closeTo(board.width * (kIsWeb ? 2 : 1), 0.1));
        }
        await tester.dragFrom(editor.center, const Offset(70, 25));
        expect(drags, greaterThan(0));
        await tester.tap(find.text('Start'));
        expect(starts, 1);
        expect(tester.takeException(), null);
      },
    );
  }
}

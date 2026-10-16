import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/game/widgets_game_scrollable_workspace.dart';

/// Native WebViews must not compete with enclosing Flutter drag scroll views.
class ScratchWorkspace extends StatelessWidget {
  const ScratchWorkspace({
    super.key,
    required this.editor,
    required this.board,
    this.editorWidth = 600,
  });

  final Widget editor;
  final Widget board;
  final double editorWidth;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return GameScrollableWorkspace(
        minWidth: 720,
        minHeight: 520,
        child: Row(
          children: [
            SizedBox(width: editorWidth, child: editor),
            Expanded(child: board),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final parts = [
          Expanded(child: ClipRect(child: editor)),
          const SizedBox(width: 8, height: 8),
          Expanded(child: ClipRect(child: board)),
        ];
        return Padding(
          padding: const EdgeInsets.all(8),
          // Keep the same element tree when rotating: do not recreate WebView.
          child: Flex(
            direction: constraints.maxWidth < 600
                ? Axis.vertical
                : Axis.horizontal,
            children: parts,
          ),
        );
      },
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Native WebViews must not compete with enclosing Flutter drag scroll views.
class ScratchWorkspace extends StatelessWidget {
  const ScratchWorkspace({
    super.key,
    required this.editor,
    required this.board,
  });

  final Widget editor;
  final Widget board;
  // Half of the wide Web editor is the palette: 2:1 makes three equal regions.
  static int editorFlexFor({required double width, required bool web}) =>
      web && width >= 600 ? 2 : 1;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parts = [
          Expanded(
            flex: editorFlexFor(width: constraints.maxWidth, web: kIsWeb),
            child: ClipRect(child: editor),
          ),
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

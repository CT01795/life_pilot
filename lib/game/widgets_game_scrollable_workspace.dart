import 'dart:math';

import 'package:flutter/material.dart';

/// Keeps wide/tall game workspaces usable on phones and short landscape
/// screens without relying on an edge swipe that can trigger system back.
class GameScrollableWorkspace extends StatefulWidget {
  const GameScrollableWorkspace({
    super.key,
    required this.child,
    required this.minWidth,
    required this.minHeight,
  });

  final Widget child;
  final double minWidth;
  final double minHeight;

  @override
  State<GameScrollableWorkspace> createState() =>
      _GameScrollableWorkspaceState();
}

class _GameScrollableWorkspaceState extends State<GameScrollableWorkspace> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final needsHorizontalScroll = constraints.maxWidth < widget.minWidth;
        final needsVerticalScroll = constraints.maxHeight < widget.minHeight;
        final scrollbarThickness = needsHorizontalScroll ? 10.0 : 6.0;
        final contentWidth = max(widget.minWidth, constraints.maxWidth);
        final contentHeight = max(widget.minHeight, constraints.maxHeight);

        return Scrollbar(
          controller: _verticalController,
          thumbVisibility: needsVerticalScroll,
          interactive: true,
          thickness: needsVerticalScroll ? 10 : 6,
          radius: const Radius.circular(8),
          scrollbarOrientation: ScrollbarOrientation.right,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.vertical,
          child: SingleChildScrollView(
            controller: _verticalController,
            scrollDirection: Axis.vertical,
            physics: const ClampingScrollPhysics(),
            child: Padding(
              // Keep the horizontal thumb away from Android's edge-back zone.
              padding: EdgeInsets.symmetric(
                horizontal: needsHorizontalScroll ? 12 : 0,
              ),
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: needsHorizontalScroll,
                interactive: true,
                thickness: scrollbarThickness,
                radius: const Radius.circular(8),
                scrollbarOrientation: ScrollbarOrientation.bottom,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.only(
                    right: needsVerticalScroll ? 22 : 0,
                    bottom: needsHorizontalScroll ? 22 : 0,
                  ),
                  child: SizedBox(
                    width: contentWidth,
                    height: contentHeight,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

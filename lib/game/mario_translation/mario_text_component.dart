import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// Draws wrapped text directly, without walking Flame TextBox line boundaries.
/// The painter is reused until text changes; it never lays out in update().
class MarioTextComponent extends PositionComponent {
  final double maxWidth;
  final TextStyle style;
  final EdgeInsets padding;
  String _text;
  TextPainter? _painter;

  MarioTextComponent({
    required String text,
    required this.maxWidth,
    required this.style,
    this.padding = EdgeInsets.zero,
    super.position,
    super.anchor,
  }) : _text = text {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      throw ArgumentError.value(
        maxWidth,
        'maxWidth',
        'Must be finite and positive',
      );
    }
    _layout();
  }

  String get text => _text;
  set text(String value) {
    if (_text == value) return;
    _text = value;
    _layout();
  }

  void _layout() {
    final painter = _painter ??= TextPainter(textDirection: TextDirection.ltr);
    painter.text = TextSpan(text: _text, style: style);
    painter.layout(maxWidth: math.max(1, maxWidth - padding.horizontal));
    size.setValues(maxWidth, painter.height + padding.vertical);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _painter?.paint(canvas, Offset(padding.left, padding.top));
  }

  @override
  void onMount() {
    if (_painter == null) _layout();
    super.onMount();
  }

  @override
  void onRemove() {
    _painter?.dispose();
    _painter = null;
    super.onRemove();
  }
}

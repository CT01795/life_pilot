import 'package:flutter/widgets.dart';

/// Shared responsive type scale for text that players must read or answer.
/// It keeps phone questions comfortably large while allowing long content to
/// wrap instead of overflowing on narrow screens.
abstract final class GameTextSizing {
  static double question(
    BuildContext context,
    String text, {
    bool dense = false,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    var size = switch (width) {
      < 360 => 30.0,
      < 480 => 34.0,
      < 720 => 36.0,
      < 1100 => 40.0,
      _ => 44.0,
    };
    if (dense) size -= 4;
    if (text.length > 120) {
      size -= 6;
    } else if (text.length > 60) {
      size -= 3;
    }
    return size.clamp(26.0, 44.0);
  }

  static double answer(BuildContext context, String text) {
    final width = MediaQuery.sizeOf(context).width;
    var size = switch (width) {
      < 360 => 26.0,
      < 480 => 29.0,
      < 720 => 31.0,
      < 1100 => 34.0,
      _ => 36.0,
    };
    if (text.length > 80) {
      size -= 5;
    } else if (text.length > 40) {
      size -= 2;
    }
    return size.clamp(24.0, 36.0);
  }
}

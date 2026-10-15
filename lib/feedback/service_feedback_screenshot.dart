import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/rendering.dart';
import 'package:life_pilot/utils/app_navigator.dart'
    show rootRepaintBoundaryKey;

class ServiceFeedbackScreenshot {
  Future<Uint8List?> capture() async {
    final renderObject = rootRepaintBoundaryKey.currentContext
        ?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;
    final image = await renderObject.toImage(pixelRatio: 3.0);
    try {
      final bytes = await image.toByteData(format: ImageByteFormat.png);
      return bytes?.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
    } finally {
      // Release the GPU-backed image even when PNG encoding fails.
      image.dispose();
    }
  }
}

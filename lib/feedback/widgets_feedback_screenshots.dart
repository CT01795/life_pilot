import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:life_pilot/feedback/model_feedback.dart';
import 'package:life_pilot/utils/const.dart';

/// View-only gallery. The model owns decoding and its per-image future cache.
/// Off-screen images are not decoded eagerly or kept alive by this list.
class WidgetsFeedbackScreenshots extends StatelessWidget {
  const WidgetsFeedbackScreenshots({super.key, required this.feedback});
  final ModelFeedback feedback;
  static const _size = 120.0;

  @override
  Widget build(BuildContext context) {
    final count = feedback.screenshot?.length ?? 0;
    if (count == 0) return const SizedBox.shrink();
    final cacheSize = (_size * MediaQuery.devicePixelRatioOf(context)).round();
    return SizedBox(
      width: double.maxFinite,
      height: _size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        scrollCacheExtent: const ScrollCacheExtent.pixels(0),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemCount: count,
        separatorBuilder: (_, _) => Gaps.w8,
        itemBuilder: (context, index) => FutureBuilder<Uint8List?>(
          future: feedback.decodeScreenshotAsync(index),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox.square(
                dimension: _size,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final bytes = snapshot.data;
            if (bytes == null) return _brokenImage(context);
            return GestureDetector(
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  child: InteractiveViewer(
                    child: Image.memory(
                      bytes,
                      errorBuilder: (context, _, _) => _brokenImage(context),
                    ),
                  ),
                ),
              ),
              child: Image.memory(
                bytes,
                width: _size,
                height: _size,
                fit: BoxFit.cover,
                cacheWidth: cacheSize,
                cacheHeight: cacheSize,
                filterQuality: FilterQuality.low,
                errorBuilder: (context, _, _) => _brokenImage(context),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _brokenImage(BuildContext context) => SizedBox.square(
    dimension: _size,
    child: Icon(
      Icons.broken_image_outlined,
      size: 44,
      color: Theme.of(context).colorScheme.error,
    ),
  );
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Uint8List? _decodeBase64Image(String encoded) {
  try {
    return base64Decode(encoded);
  } catch (_) {
    return null;
  }
}

class WidgetsEventImage extends StatefulWidget {
  final String? value;
  final double height;

  const WidgetsEventImage({
    super.key,
    required this.value,
    this.height = 180,
  });

  @override
  State<WidgetsEventImage> createState() => _WidgetsEventImageState();
}

class _WidgetsEventImageState extends State<WidgetsEventImage> {
  String? _decodedValue;
  Future<Uint8List?>? _decodeFuture;

  @override
  Widget build(BuildContext context) {
    final imageValue = widget.value?.trim();
    if (imageValue == null || imageValue.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: _buildImage(context, imageValue),
    );
  }

  Widget _buildImage(BuildContext context, String imageValue) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (MediaQuery.sizeOf(context).width * pixelRatio).round();
    final cacheHeight = (widget.height * pixelRatio).round();
    if (imageValue.startsWith('http://') || imageValue.startsWith('https://')) {
      return Image.network(
        imageValue,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: FilterQuality.low,
        frameBuilder: _buildFrame,
        errorBuilder: (_, __, ___) => _buildErrorPlaceholder(context),
      );
    }
    return FutureBuilder<Uint8List?>(
      future: _decodeImage(imageValue),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoadingPlaceholder(context);
        }
        final bytes = snapshot.data;
        if (bytes == null) return _buildErrorPlaceholder(context);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          filterQuality: FilterQuality.low,
          frameBuilder: _buildFrame,
          errorBuilder: (_, __, ___) => _buildErrorPlaceholder(context),
        );
      },
    );
  }

  Widget _buildFrame(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (wasSynchronouslyLoaded) return child;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      child: frame == null
          ? KeyedSubtree(
              key: const ValueKey('loading'),
              child: _buildLoadingPlaceholder(context),
            )
          : KeyedSubtree(
              key: const ValueKey('image'),
              child: child,
            ),
    );
  }

  Widget _buildLoadingPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 34,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 34,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
      ),
    );
  }

  Future<Uint8List?> _decodeImage(String imageValue) {
    if (_decodedValue == imageValue && _decodeFuture != null) {
      return _decodeFuture!;
    }
    _decodedValue = imageValue;
    final encoded = imageValue.contains(',')
        ? imageValue.substring(imageValue.indexOf(',') + 1)
        : imageValue;
    return _decodeFuture = compute(_decodeBase64Image, encoded);
  }
}

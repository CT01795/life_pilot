import 'dart:convert';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Uint8List? _decodeBase64Image(String encoded) {
  try {
    return base64Decode(encoded);
  } catch (_) {
    return null;
  }
}

class _DecodedImageEntry {
  _DecodedImageEntry(this.future);

  final Future<Uint8List?> future;
  int byteLength = 0;
}

class _DecodedImageCache {
  static const int _maxEntries = 8;
  static const int _maxBytes = 24 * 1024 * 1024;
  static final LinkedHashMap<String, _DecodedImageEntry> _entries =
      LinkedHashMap<String, _DecodedImageEntry>();
  static int _totalBytes = 0;

  static Future<Uint8List?> decode(String imageValue) {
    final cached = _entries.remove(imageValue);
    if (cached != null) {
      _entries[imageValue] = cached;
      return cached.future;
    }

    final encoded = imageValue.contains(',')
        ? imageValue.substring(imageValue.indexOf(',') + 1)
        : imageValue;
    final entry = _DecodedImageEntry(compute(_decodeBase64Image, encoded));
    _entries[imageValue] = entry;
    _trim();
    entry.future.then((bytes) {
      if (!identical(_entries[imageValue], entry)) return;
      if (bytes == null) {
        _entries.remove(imageValue);
        return;
      }
      entry.byteLength = bytes.lengthInBytes;
      _totalBytes += entry.byteLength;
      _trim();
    });
    return entry.future;
  }

  static void _trim() {
    while (_entries.length > _maxEntries ||
        (_totalBytes > _maxBytes && _entries.length > 1)) {
      final oldestKey = _entries.keys.first;
      final removed = _entries.remove(oldestKey);
      _totalBytes -= removed?.byteLength ?? 0;
    }
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
    return _decodeFuture = _DecodedImageCache.decode(imageValue);
  }
}

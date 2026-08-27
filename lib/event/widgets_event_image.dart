import 'dart:convert';

import 'package:flutter/material.dart';

class WidgetsEventImage extends StatelessWidget {
  final String? value;
  final double height;

  const WidgetsEventImage({
    super.key,
    required this.value,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    final imageValue = value?.trim();
    if (imageValue == null || imageValue.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: double.infinity,
      height: height,
      child: _buildImage(context, imageValue),
    );
  }

  Widget _buildImage(BuildContext context, String imageValue) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (MediaQuery.sizeOf(context).width * pixelRatio).round();
    final cacheHeight = (height * pixelRatio).round();
    if (imageValue.startsWith('http://') || imageValue.startsWith('https://')) {
      return Image.network(
        imageValue,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    final encoded = imageValue.contains(',')
        ? imageValue.substring(imageValue.indexOf(',') + 1)
        : imageValue;
    try {
      return Image.memory(
        base64Decode(encoded),
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}

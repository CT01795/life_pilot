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
      child: _buildImage(imageValue),
    );
  }

  Widget _buildImage(String imageValue) {
    if (imageValue.startsWith('http://') || imageValue.startsWith('https://')) {
      return Image.network(
        imageValue,
        fit: BoxFit.cover,
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
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}

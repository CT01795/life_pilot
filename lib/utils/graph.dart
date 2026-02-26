import 'dart:convert';
import 'package:flutter/services.dart';

Uint8List? decodeBase64InIsolate(String? data) {
  if (data == null) return null;
  try {
    return base64Decode(data);
  } catch (_) {
    return null;
  }
}

Future<bool> assetExists(String assetPath) async {
  try {
    await rootBundle.load(assetPath);
    return true;
  } catch (e) {
    return false;
  }
}
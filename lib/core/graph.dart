import 'dart:convert';
import 'package:flutter/foundation.dart';

Uint8List? decodeBase64InIsolate(String? data) {
  if (data == null) return null;
  try {
    return base64Decode(data);
  } catch (_) {
    return null;
  }
}
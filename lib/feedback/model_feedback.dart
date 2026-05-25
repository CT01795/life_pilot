import 'dart:convert';

import 'package:flutter/foundation.dart';

class ModelFeedback {
  final int id;
  final String subject;
  final String content;
  final List<String>? cc;
  List<String>? screenshot; // base64
  final String? createdBy;
  final DateTime createdAt;
  List<Uint8List>? screenshotDecodeRawData; // decode cache
  bool? isOk;
  String? dealBy;
  DateTime? dealAt;

  ModelFeedback({
    required this.id,
    required this.subject,
    required this.content,
    this.cc,
    this.screenshot,
    this.createdBy,
    required this.createdAt,
    this.isOk,
    this.dealBy,
    this.dealAt,
  });

  factory ModelFeedback.fromMap(Map<String, dynamic> map) {
    return ModelFeedback(
      id: int.parse(map['id'].toString()),
      subject: map['subject'] as String,
      content: map['content'] as String,
      cc: (map['cc'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      screenshot: (map['screenshot'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      createdBy: map['created_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      isOk: map['is_ok'] is bool
          ? map['is_ok']
          : map['is_ok']?.toString() == 'true',
      dealBy: map['deal_by'] as String?,
      dealAt: map['deal_at'] != null && map['deal_at'].toString().isNotEmpty
          ? DateTime.parse(map['deal_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'is_ok': isOk ?? false,
        'deal_by': dealBy,
        'deal_at': dealAt?.toIso8601String(),
      };

  // 💡 懶加載 decode，第一次用時才 decode，之後 cache
  List<Uint8List>? get screenshotDecodeData {
    if (screenshotDecodeRawData != null) return screenshotDecodeRawData;
    if (screenshot == null) return null;
    screenshotDecodeRawData = screenshot?.map(base64Decode).toList();
    return screenshotDecodeRawData;
  }

  Future<List<Uint8List>> decodeScreenshotsAsync() async {
    if (screenshotDecodeRawData != null) return screenshotDecodeRawData!;
    if (screenshot == null) return [];

    // async decode
    final decoded =
        await Future.wait(screenshot!.map((s) => compute(decodeBase64, s)));
    screenshotDecodeRawData = decoded;
    return decoded;
  }

  // helper for isolate
  static Uint8List decodeBase64(String s) => base64Decode(s);
}

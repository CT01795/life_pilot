import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';

class ModelFeedback {
  final int id;
  final String subject;
  final String content;
  final List<String>? cc;
  List<String>? screenshot; // base64
  final String? createdBy;
  final DateTime createdAt;
  List<Uint8List>? screenshotDecodeRawData; // decode cache
  Future<List<Uint8List>>? _screenshotDecodeFuture;
  final Map<int, Future<Uint8List?>> _screenshotDecodeFutures = {};
  bool? isOk;
  String? dealBy;
  DateTime? dealAt;
  String status;

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
    this.status = 'pending',
  });

  factory ModelFeedback.fromMap(Map<String, dynamic> map) {
    return ModelFeedback(
      id: parseIntValue(map[Fields.id]),
      subject: parseStringValue(map['subject']),
      content: parseStringValue(map['content']),
      cc: (map['cc'] as List<dynamic>?)?.map(parseStringValue).toList(),
      screenshot: (map['screenshot'] as List<dynamic>?)
          ?.map(parseStringValue)
          .toList(),
      createdBy: parseStringValue(map[Fields.createdBy]),
      createdAt: tryParseDateTimeValue(map[Fields.createdAt]) ?? DateTime.now(),
      isOk: map['is_ok'] is bool
          ? map['is_ok']
          : parseStringValue(map['is_ok']).toLowerCase() == 'true',
      dealBy: parseStringValue(map['deal_by']),
      dealAt: parseStringValue(map['deal_at']).trim().isNotEmpty
          ? tryParseDateTimeValue(map['deal_at'])
          : null,
      status: parseStringValue(
        map['status'],
        fallback: map['is_ok'] == true ? 'completed' : 'pending',
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    Fields.id: id,
    'is_ok': isOk ?? false,
    'deal_by': dealBy,
    'deal_at': dealAt?.toUtc().toIso8601String(),
    'status': status,
  };

  /// Proposed status for persistence; the displayed record is unchanged.
  ModelFeedback withStatus(String nextStatus, String admin, DateTime now) =>
      ModelFeedback(
        id: id,
        subject: subject,
        content: content,
        cc: cc,
        screenshot: screenshot,
        createdBy: createdBy,
        createdAt: createdAt,
        status: nextStatus,
        isOk: nextStatus == 'completed',
        dealBy: nextStatus == 'pending' ? null : admin,
        dealAt: nextStatus == 'completed' ? now.toUtc() : null,
      );

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
    return _screenshotDecodeFuture ??= _decodeScreenshots();
  }

  Future<Uint8List?> decodeScreenshotAsync(int index) {
    final screenshots = screenshot;
    if (screenshots == null || index < 0 || index >= screenshots.length) {
      return Future.value();
    }
    return _screenshotDecodeFutures.putIfAbsent(index, () async {
      try {
        return await compute(decodeBase64, screenshots[index]);
      } catch (_) {
        return null;
      }
    });
  }

  Future<List<Uint8List>> _decodeScreenshots() async {
    try {
      final decoded = await Future.wait(
        screenshot!.map((s) => compute(decodeBase64, s)),
      );
      screenshotDecodeRawData = decoded;
      return decoded;
    } catch (_) {
      _screenshotDecodeFuture = null;
      rethrow;
    }
  }

  // helper for isolate
  static Uint8List decodeBase64(String s) => base64Decode(s);
}

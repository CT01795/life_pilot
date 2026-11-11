import 'dart:async';
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
  bool screenshotsLoaded;
  final String? createdBy;
  final DateTime createdAt;
  final _screenshotDecodeFutures =
      <int, ({String source, Future<Uint8List?> value})>{};
  final Future<Uint8List> Function(String) _screenshotDecoder;
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
    this.screenshotsLoaded = true,
    this.createdBy,
    required this.createdAt,
    this.isOk,
    this.dealBy,
    this.dealAt,
    this.status = 'pending',
    Future<Uint8List> Function(String)? screenshotDecoder,
  }) : _screenshotDecoder = screenshotDecoder ?? _decodeOffThread;

  factory ModelFeedback.fromMap(Map<String, dynamic> map) {
    return ModelFeedback(
      id: parseIntValue(map[Fields.id]),
      subject: parseStringValue(map['subject']),
      content: parseStringValue(map['content']),
      cc: (map['cc'] as List<dynamic>?)?.map(parseStringValue).toList(),
      screenshot: (map['screenshot'] as List<dynamic>?)
          ?.map(parseStringValue)
          .toList(),
      screenshotsLoaded: map.containsKey('screenshot'),
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
        screenshotDecoder: _screenshotDecoder,
        createdBy: createdBy,
        createdAt: createdAt,
        status: nextStatus,
        isOk: nextStatus == 'completed',
        dealBy: nextStatus == 'pending' ? null : admin,
        dealAt: nextStatus == 'completed' ? now.toUtc() : null,
      );

  Future<Uint8List?> decodeScreenshotAsync(int index) {
    final screenshots = screenshot;
    if (screenshots == null || index < 0 || index >= screenshots.length) {
      return Future.value();
    }
    final source = screenshots[index];
    final cached = _screenshotDecodeFutures[index];
    if (cached != null && cached.source == source) return cached.value;
    final completion = Completer<Uint8List?>();
    final future = completion.future;
    _screenshotDecodeFutures[index] = (source: source, value: future);
    // _decodeScreenshot maps decoder errors to null for the broken thumbnail.
    // Register first so synchronous decoder re-entry cannot start another job.
    unawaited(_decodeScreenshot(source).then<void>(completion.complete));
    return future;
  }

  Future<Uint8List?> _decodeScreenshot(String source) async {
    try {
      return await _screenshotDecoder(source);
    } catch (_) {
      return null;
    }
  }

  // helper for isolate
  static Uint8List _decodeBase64(String s) => base64Decode(s);
  static Future<Uint8List> _decodeOffThread(String source) =>
      compute(_decodeBase64, source);
}

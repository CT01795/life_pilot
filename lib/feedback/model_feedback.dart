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
  List<Uint8List>? _decodedScreenshots;
  List<String>? _decodedSource;
  Future<List<Uint8List>>? _screenshotDecodeFuture;
  List<String>? _screenshotDecodeSource;
  Object? _screenshotDecodeToken;
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

  /// A decoded batch belongs to an exact source snapshot, including when the
  /// public screenshot list is edited in place by an existing caller.
  List<Uint8List>? get screenshotDecodeRawData =>
      listEquals(screenshot, _decodedSource) ? _decodedScreenshots : null;

  set screenshotDecodeRawData(List<Uint8List>? value) {
    _decodedScreenshots = value;
    _decodedSource = screenshot == null ? null : List.of(screenshot!);
    _screenshotDecodeFutures.clear();
    _screenshotDecodeToken = null;
    _screenshotDecodeFuture = null;
    _screenshotDecodeSource = null;
  }

  List<Uint8List>? get screenshotDecodeData {
    final cached = screenshotDecodeRawData;
    if (cached != null) return cached;
    final images = screenshot;
    if (images == null) return null;
    final decoded = images.map(base64Decode).toList();
    screenshotDecodeRawData = decoded;
    return decoded;
  }

  Future<List<Uint8List>> decodeScreenshotsAsync() {
    final decoded = screenshotDecodeRawData;
    if (decoded != null) return Future.value(decoded);
    final images = screenshot;
    if (images == null) return Future.value([]);
    if (_screenshotDecodeFuture != null &&
        listEquals(images, _screenshotDecodeSource)) {
      return _screenshotDecodeFuture!;
    }
    final source = List<String>.of(images, growable: false);
    final token = Object();
    _screenshotDecodeSource = source;
    _screenshotDecodeToken = token;
    return _screenshotDecodeFuture = _decodeScreenshots(source, token);
  }

  Future<Uint8List?> decodeScreenshotAsync(int index) {
    final screenshots = screenshot;
    if (screenshots == null || index < 0 || index >= screenshots.length) {
      return Future.value();
    }
    final source = screenshots[index];
    final cached = _screenshotDecodeFutures[index];
    if (cached != null && cached.source == source) return cached.value;
    // Validate this index only: lazy thumbnails must not scan every image.
    final decoded = _decodedScreenshots;
    final decodedSource = _decodedSource;
    final future =
        decoded != null &&
            decodedSource != null &&
            index < decoded.length &&
            index < decodedSource.length &&
            decodedSource[index] == source
        ? Future<Uint8List?>.value(decoded[index])
        : _decodeScreenshot(source);
    _screenshotDecodeFutures[index] = (source: source, value: future);
    return future;
  }

  Future<Uint8List?> _decodeScreenshot(String source) async {
    try {
      return await _screenshotDecoder(source);
    } catch (_) {
      return null;
    }
  }

  Future<List<Uint8List>> _decodeScreenshots(
    List<String> source,
    Object token,
  ) async {
    try {
      final decoded = await Future.wait(
        source.map(
          (image) => Future<Uint8List>.sync(() => _screenshotDecoder(image)),
        ),
      );
      if (identical(token, _screenshotDecodeToken) &&
          listEquals(screenshot, source)) {
        _decodedScreenshots = decoded;
        _decodedSource = source;
      }
      return decoded;
    } catch (_) {
      if (identical(token, _screenshotDecodeToken)) {
        _screenshotDecodeFuture = null;
        _screenshotDecodeSource = null;
      }
      rethrow;
    }
  }

  // helper for isolate
  static Uint8List decodeBase64(String s) => base64Decode(s);
  static Future<Uint8List> _decodeOffThread(String source) =>
      compute(decodeBase64, source);
}

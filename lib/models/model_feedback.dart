import 'dart:convert';
import 'dart:typed_data';

class ModelFeedback {
  final int id;
  final String subject;
  final String content;
  final List<String>? cc;
  final List<String>? screenshot; // base64
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
      id: map['id'] as int,
      subject: map['subject'] as String,
      content: map['content'] as String,
      cc: (map['cc'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      screenshot: (map['screenshot'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      createdBy: map['created_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      isOk: map['is_ok'] as bool?,
      dealBy: map['deal_by'] as String?,
      dealAt: map['deal_at'] != null ? DateTime.parse(map['deal_at']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'is_ok': isOk,
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
}

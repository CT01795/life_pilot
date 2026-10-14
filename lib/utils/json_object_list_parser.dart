import 'dart:convert';

/// Reads object arrays from database JSON or serialized local-storage JSON.
/// Non-object entries are ignored; malformed or non-array JSON is empty.
List<Map<String, dynamic>> parseJsonObjectList(Object? value) {
  Object? parsed = value;
  if (value is String) {
    if (value.trim().isEmpty) return const [];
    try {
      parsed = jsonDecode(value);
    } on FormatException {
      return const [];
    }
  }
  if (parsed is! List) return const [];
  return parsed
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

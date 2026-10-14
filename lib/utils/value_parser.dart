/// Converts loosely typed database and local-storage values consistently.
///
/// Supabase, IndexedDB, and imported JSON may represent the same value as a
/// Dart number or as text. Keeping these conversions here prevents model and
/// service layers from each implementing slightly different rules.
num? tryParseNumValue(Object? value) {
  if (value is num) return value;
  return num.tryParse(value?.toString().trim() ?? '');
}

/// Converts nullable API/local values to text without repeated null handling.
String parseStringValue(Object? value, {String fallback = ''}) =>
    value?.toString() ?? fallback;

num parseNumValue(Object? value, {num fallback = 0}) =>
    tryParseNumValue(value) ?? fallback;

int? tryParseIntValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}

int parseIntValue(Object? value, {int fallback = 0}) =>
    tryParseIntValue(value) ?? fallback;

double? tryParseDoubleValue(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().trim() ?? '');
}

double parseDoubleValue(Object? value, {double fallback = 0}) =>
    tryParseDoubleValue(value) ?? fallback;

DateTime? tryParseDateTimeValue(Object? value, {bool toLocal = false}) {
  final parsed = value is DateTime
      ? value
      : DateTime.tryParse(value?.toString().trim() ?? '');
  if (parsed == null) return null;
  return toLocal ? parsed.toLocal() : parsed;
}

bool parseBoolValue(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) {
    if (value == 1) return true;
    if (value == 0) return false;
    return fallback;
  }
  return switch (value?.toString().trim().toLowerCase()) {
    'true' || 't' || '1' => true,
    'false' || 'f' || '0' => false,
    _ => fallback,
  };
}

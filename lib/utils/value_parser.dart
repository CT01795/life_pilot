/// Converts loosely typed database and local-storage values consistently.
///
/// Supabase, IndexedDB, and imported JSON may represent the same value as a
/// Dart number or as text. Keeping these conversions here prevents model and
/// service layers from each implementing slightly different rules.
num? tryParseNumValue(Object? value) {
  if (value is num) return value;
  final text = _nonEmptyValueText(value);
  return text == null ? null : num.tryParse(text);
}

/// Skip parsing absent database fields, while stringifying other values only
/// once. Native numeric/date values keep their existing typed fast paths.
String? _nonEmptyValueText(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

/// Converts nullable API/local values to text without repeated null handling.
String parseStringValue(Object? value, {String fallback = ''}) =>
    value?.toString() ?? fallback;

/// Preserves null when an optional model field is absent.
String? parseOptionalStringValue(Object? value) => value?.toString();

/// Normalizes loosely typed text for case-insensitive comparisons.
String normalizeStringValue(Object? value) =>
    parseStringValue(value).trim().toLowerCase();

/// Formats small integer date/time parts consistently across services and UI.
String padIntValue(int value, {int width = 2}) =>
    value.toString().padLeft(width, '0');

num parseNumValue(Object? value, {num fallback = 0}) =>
    tryParseNumValue(value) ?? fallback;

int? tryParseIntValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  final text = _nonEmptyValueText(value);
  return text == null ? null : int.tryParse(text);
}

int parseIntValue(Object? value, {int fallback = 0}) =>
    tryParseIntValue(value) ?? fallback;

double? tryParseDoubleValue(Object? value) {
  if (value is num) return value.toDouble();
  final text = _nonEmptyValueText(value);
  return text == null ? null : double.tryParse(text);
}

double parseDoubleValue(Object? value, {double fallback = 0}) =>
    tryParseDoubleValue(value) ?? fallback;

DateTime? tryParseDateTimeValue(Object? value, {bool toLocal = false}) {
  if (value is DateTime) return toLocal ? value.toLocal() : value;
  final text = _nonEmptyValueText(value);
  if (text == null) return null;
  final parsed = DateTime.tryParse(text);
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

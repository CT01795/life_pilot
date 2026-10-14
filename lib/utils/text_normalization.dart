import 'package:life_pilot/utils/value_parser.dart';

/// Normalizes user-entered identifiers and searchable text consistently.
///
/// Keeping this rule in one place prevents account cache keys, ownership
/// checks, and database parameters from drifting apart over time.
String normalizeText(Object? value) =>
    normalizeStringValue(value);

/// Compares values after trimming surrounding whitespace and ignoring case.
bool normalizedTextEquals(Object? left, Object? right) =>
    normalizeText(left) == normalizeText(right);

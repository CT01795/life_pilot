import 'package:flutter/material.dart';
import 'package:life_pilot/utils/value_parser.dart';

class EventDateTimeParser {
  const EventDateTimeParser._();

  static DateTime? parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return tryParseDateTimeValue(value.replaceAll('/', '-'), toLocal: true);
  }

  static TimeOfDay? parseTime(String? value) {
    if (value == null) return null;

    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) return null;

    return TimeOfDay(
      hour: parseIntValue(match.group(1)),
      minute: parseIntValue(match.group(2)),
    );
  }
}

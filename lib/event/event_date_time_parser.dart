import 'package:flutter/material.dart';

class EventDateTimeParser {
  const EventDateTimeParser._();

  static DateTime? parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value.replaceAll('/', '-'))?.toLocal();
  }

  static TimeOfDay? parseTime(String? value) {
    if (value == null) return null;

    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) return null;

    return TimeOfDay(
      hour: int.parse(match.group(1)!),
      minute: int.parse(match.group(2)!),
    );
  }
}

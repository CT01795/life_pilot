import 'package:flutter/material.dart';

DateTime replaceRecordDate(DateTime source, DateTime date) => DateTime(
  date.year,
  date.month,
  date.day,
  source.hour,
  source.minute,
  source.second,
  source.millisecond,
  source.microsecond,
);

DateTime replaceRecordTime(DateTime source, TimeOfDay time) => DateTime(
  source.year,
  source.month,
  source.day,
  time.hour,
  time.minute,
  source.second,
  source.millisecond,
  source.microsecond,
);

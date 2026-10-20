import 'dart:ui';
import 'package:life_pilot/local_storage/local_data_store.dart';

/// Immutable inputs captured before starting asynchronous month loading.
class ModelCalendarMonthQuery {
  final DateTime month;
  final DateTime start;
  final DateTime end;
  final String? account;
  final DataStorageLocation? storage;
  final Locale locale;
  final String tableName;

  const ModelCalendarMonthQuery({
    required this.month,
    required this.start,
    required this.end,
    required this.account,
    required this.storage,
    required this.locale,
    required this.tableName,
  });
}

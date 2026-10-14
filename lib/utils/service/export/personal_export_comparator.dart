import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';

typedef PersonalExportRow = Map<String, dynamic>;

/// Keeps workbook row order independent of download and localization code.
Comparator<PersonalExportRow> personalExportComparator(String tableName) {
  final isAccount =
      tableName == TableNames.accountingAccount ||
      tableName == TableNames.pointRecordAccount;
  final isDetail = tableName.contains('detail');
  final dateKey = isDetail ? 'date' : 'start_date';

  return (a, b) {
    if (isAccount) {
      return parseStringValue(a['account_name']).toLowerCase().compareTo(
        parseStringValue(b['account_name']).toLowerCase(),
      );
    }
    if (isDetail) {
      final account = _compareField(a, b, 'account_name');
      if (account != 0) return account;
    }
    final date = _compareField(a, b, dateKey);
    if (date != 0) return date;
    final time = parseStringValue(
      a['start_time'] ?? a['time'],
    ).compareTo(parseStringValue(b['start_time'] ?? b['time']));
    if (time != 0) return time;
    if (isDetail) return _compareField(a, b, 'description');

    final endDate =
        parseStringValue(
          a['end_date'],
          fallback: parseStringValue(a['start_date']),
        ).compareTo(
          parseStringValue(
            b['end_date'],
            fallback: parseStringValue(b['start_date']),
          ),
        );
    if (endDate != 0) return endDate;
    for (final key in const ['end_time', 'city', 'location', 'name']) {
      final result = _compareField(a, b, key);
      if (result != 0) return result;
    }
    return 0;
  };
}

int _compareField(PersonalExportRow a, PersonalExportRow b, String key) =>
    parseStringValue(a[key]).compareTo(parseStringValue(b[key]));

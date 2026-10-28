import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/utils/const.dart';

/// Fixed cloud query values captured once before pagination. No requests,
/// credentials, shared account cache or widget state belong in this model.
class ModelRecordStatisticsQuery {
  final String tableName;
  final String columns;
  final String? currency;
  final String? startUtc;
  final String? endUtc;

  ModelRecordStatisticsQuery({
    required RecordStatisticsKind kind,
    required DateTime now,
    String? currency,
    bool history = false,
  }) : tableName = kind == RecordStatisticsKind.accounting
           ? TableNames.accountingDetail
           : TableNames.pointRecordDetail,
       columns = kind == RecordStatisticsKind.accounting
           ? 'id,date,value,currency'
           : 'id,date,value',
       currency = kind == RecordStatisticsKind.accounting ? currency : null,
       startUtc = history
           ? null
           : DateTime(now.year, now.month).toUtc().toIso8601String(),
       endUtc = history
           ? null
           : DateTime(now.year, now.month + 1).toUtc().toIso8601String();
}

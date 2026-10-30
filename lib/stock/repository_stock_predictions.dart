import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/model_stock_predictions.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The newest prediction snapshot and its date are read atomically in one
/// authenticated request. Historical reads use an explicit UTC day window;
/// server-side updates remain separate.
class RepositoryStockPredictions {
  RepositoryStockPredictions({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;

  /// Fallback for callers that need only the date, not the prediction payload.
  /// Normal initial loading still uses readLatest() in a single request.
  Future<DateTime?> readLatestDate() async {
    final rows = await (_client ?? supabase)
        .from(TableNames.stockPredicted)
        .select('date')
        .order('date', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return tryParseDateTimeValue(rows.first['date']);
  }

  Future<List<ModelStock>> readLatest() async {
    final rows = await (_client ?? supabase)
        .from(TableNames.stockPredicted)
        .select('date,data')
        .order('date', ascending: false)
        .limit(1);
    if (rows.isEmpty || rows.first['data'] is! List) return [];
    return ModelStockPredictions.decode(
      rows.first['data'] as List,
      origin: StockDataOrigin.cloud,
    );
  }

  Future<List<ModelStock>> readDate(DateTime date) async {
    // Preserve selected calendar-day semantics, not date.toUtc() (which can
    // shift a local midnight into the previous day).
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows = await (_client ?? supabase)
        .from(TableNames.stockPredicted)
        .select('data')
        .gte('date', start.toIso8601String())
        .lt('date', end.toIso8601String())
        .limit(1);
    if (rows.isEmpty || rows.first['data'] is! List) return [];
    return ModelStockPredictions.decode(
      rows.first['data'] as List,
      origin: StockDataOrigin.cloud,
    );
  }
}

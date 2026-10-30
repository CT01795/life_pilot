import 'package:intl/intl.dart';
import 'package:life_pilot/stock/model_stock_futures.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authenticated, read-only cloud access. RLS remains authoritative; never
/// route failed reads through a privileged backend or embed a service key.
class RepositoryStockFutures {
  RepositoryStockFutures({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;

  Future<List<Map<String, dynamic>>> readPreviousDate(
    DateTime date, {
    required int lookbackDays,
  }) async {
    final minimum = date.subtract(Duration(days: lookbackDays));
    final rows = await (_client ?? supabase)
        .from(TableNames.futuresInstitutional)
        .select('date')
        .gte('date', DateFormat('yyyy-MM-dd').format(minimum))
        .lt('date', DateFormat('yyyy-MM-dd').format(date))
        .order('date', ascending: false)
        .limit(1);
    if (rows.isEmpty) return [];
    final previous = tryParseDateTimeValue(rows.first['date']);
    if (previous == null) throw FormatException('Invalid futures date');
    return readDate(previous);
  }

  Future<List<Map<String, dynamic>>> readDate(DateTime date) async {
    final rows = await (_client ?? supabase)
        .from(TableNames.futuresInstitutional)
        .select(
          'product_name,identity_type,oi_long_qty,oi_short_qty,oi_net_qty',
        )
        .eq('date', DateFormat('yyyy-MM-dd').format(date))
        .order('product_name')
        .order('identity_type');
    // Preserve the Render endpoint's product order, not alphabetical order.
    rows.sort(ModelStockFutures.compareRows);
    return rows;
  }
}

import 'package:intl/intl.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads only the fields used by the institutional dashboard. The Controller
/// owns ranking, concurrent requests and retry state; this layer caches nothing.
class RepositoryStockInstitutionals {
  RepositoryStockInstitutionals({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;

  Future<List<ModelInstitutional>> readDate(DateTime date) async {
    final rows = await (_client ?? supabase)
        .from(TableNames.stockInstitutional)
        .select('stock_no,stock_name,foreign_diff,total_diff')
        .eq('date', DateFormat('yyyy-MM-dd').format(date));
    return rows.map(ModelInstitutional.fromJson).toList();
  }
}

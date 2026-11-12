import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/repository_session_reads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Narrow read projections. The service still owns plan creation and writes.
class RepositoryBusinessPlanReads {
  const RepositoryBusinessPlanReads(this.client);
  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> templates() => _templateRead(
    'list',
    () async => await client
        .from(TableNames.businessPlanTemplate)
        .select('id,title,description')
        .eq(Fields.isValid, true)
        .order(Fields.createdAt, ascending: true),
  );
  Future<List<Map<String, dynamic>>> _templateRead(
    Object key,
    Future<List<Map<String, dynamic>>> Function() fetch,
  ) => RepositorySessionReads(client).read(
    'business-plan-template-reads',
    key,
    () async {
      final rows = await fetch();
      return List.unmodifiable(
        rows.map((row) => Map<String, dynamic>.unmodifiable(row)),
      );
    },
  );

  Future<List<Map<String, dynamic>>> plans({
    required String user,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await client
        .from(TableNames.businessPlan)
        .select('id,title,created_at,status')
        .eq(Fields.createdBy, user)
        .gte(Fields.createdAt, from.toUtc().toIso8601String())
        .lt(Fields.createdAt, to.toUtc().toIso8601String())
        .order(Fields.createdAt, ascending: false);
    return List.unmodifiable(
      rows.map((row) => Map<String, dynamic>.unmodifiable(row)),
    );
  }

  Future<Map<String, dynamic>> planWindow({
    required DateTime before,
    required bool seekOlder,
  }) async {
    final result = await client.rpc(
      'get_my_business_plan_window',
      params: {
        'p_before': before.toUtc().toIso8601String(),
        'p_seek_older': seekOlder,
        'p_window_days': 360,
      },
    );
    if (result is! Map) {
      throw const FormatException('Invalid business plan window');
    }
    return Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(result));
  }
}

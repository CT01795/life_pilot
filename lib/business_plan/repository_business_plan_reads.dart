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
  Future<List<Map<String, dynamic>>> sections(String templateId) =>
      _templateRead(
        ('sections', templateId),
        () async => await client
            .from(TableNames.businessPlanTemplateSection)
            .select('id,title,sort_order')
            .eq('plan_id', templateId)
            .order('sort_order', ascending: true),
      );
  Future<List<Map<String, dynamic>>> questions(String sectionId) =>
      _templateRead(
        ('questions', sectionId),
        () async => await client
            .from(TableNames.businessPlanTemplateQuestion)
            .select('prompt,sort_order')
            .eq('section_id', sectionId)
            .order('sort_order', ascending: true),
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

  // Do not share these reads across write workflows. A check performed after
  // creating/renaming a plan must not reuse a request started before that write.
  Future<Map<String, dynamic>?> existingPlan({
    required String user,
    required String title,
  }) async {
    final row = await client
        .from(TableNames.businessPlan)
        .select('id,is_valid')
        .eq(Fields.createdBy, user)
        .eq('title', title)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.unmodifiable(row);
  }

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
}

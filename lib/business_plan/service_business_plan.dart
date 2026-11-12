import 'dart:core';

import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_business_plan_window.dart';
import 'package:life_pilot/business_plan/model_plan_question.dart';
import 'package:life_pilot/business_plan/model_plan_section.dart';
import 'package:life_pilot/business_plan/model_plan_template.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/business_plan/repository_business_plan_reads.dart';

class ServiceBusinessPlan {
  ModelBusinessPlanWindow? _cachedPlanWindow;
  DateTime? _cachedPlanWindowRequestBefore;
  bool _cachedPlanWindowIsNextPage = false;

  // 1️⃣ 拉模板清單（給使用者選）
  Future<List<ModelPlanTemplate>> fetchTemplates() async {
    try {
      final res = await RepositoryBusinessPlanReads(supabase).templates();

      return (res as List)
          .map(
            (e) => ModelPlanTemplate(
              id: e[Fields.id],
              title: e['title'],
              description: e['description'] ?? '',
            ),
          )
          .toList();
    } on Exception catch (exception) {
      logger.e(exception);
      rethrow;
    }
  }

  // 2️⃣ 依模板建立企劃書內容
  /// 建立企劃書
  Future<void> createPlanFromTemplate({
    required String user,
    required String planId,
    required String title,
    required String templateId,
  }) async {
    try {
      final currentAccount = supabase.auth.currentUser?.email
          ?.trim()
          .toLowerCase();
      if (currentAccount == null ||
          currentAccount != user.trim().toLowerCase()) {
        throw StateError('Business plan account changed');
      }
      await supabase.rpc(
        'create_business_plan_from_template',
        params: {
          'p_plan_id': planId,
          'p_title': title,
          'p_template_id': templateId,
        },
      );
    } on Exception catch (exception, st) {
      logger.e(exception, stackTrace: st);
      rethrow;
    }
  }

  Future<void> updatePlanTitle({
    required String planId,
    required String title,
  }) async {
    try {
      await supabase
          .from(TableNames.businessPlan)
          .update({'title': title})
          .eq(Fields.id, planId);
    } catch (e) {
      logger.e(e);
      rethrow;
    }
  }

  Future<void> upsertAnswer({
    required String planId,
    required String sectionId,
    required String questionId,
    required String answer,
  }) async {
    try {
      // 插入新的
      await supabase.from(TableNames.businessPlanAnswer).upsert({
        'plan_id': planId,
        'section_id': sectionId,
        'question_id': questionId,
        'answer': answer,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'plan_id,section_id,question_id');
    } on Exception catch (exception) {
      logger.e(exception);
      rethrow;
    }
  }

  Future<List<ModelBusinessPlan>> fetchPlans({
    required String user,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    try {
      _requireCurrentBusinessPlanUser(user);
      final cached = _cachedPlanWindow;
      if (_cachedPlanWindowIsNextPage &&
          cached != null &&
          cached.plans.every(
            (plan) =>
                !plan.createdAt.isBefore(dateFrom) &&
                plan.createdAt.isBefore(dateTo),
          )) {
        _cachedPlanWindowIsNextPage = false;
        return List<ModelBusinessPlan>.of(cached.plans);
      }
      final window = await fetchPlanWindow(before: dateTo);
      _cachePlanWindow(window, requestBefore: dateTo, isNextPage: false);
      return List<ModelBusinessPlan>.of(window.plans);
    } on Exception catch (exception) {
      logger.e(exception);
      rethrow;
    }
  }

  void _requireCurrentBusinessPlanUser(String user) {
    final current = supabase.auth.currentUser?.email?.trim().toLowerCase();
    if (current == null || current != user.trim().toLowerCase()) {
      throw StateError('Business plan account changed');
    }
  }

  void _cachePlanWindow(
    ModelBusinessPlanWindow window, {
    required DateTime requestBefore,
    required bool isNextPage,
  }) {
    _cachedPlanWindow = window;
    _cachedPlanWindowRequestBefore = requestBefore;
    _cachedPlanWindowIsNextPage = isNextPage;
  }

  bool _sameInstant(DateTime? left, DateTime right) =>
      left != null &&
      left.toUtc().millisecondsSinceEpoch ==
          right.toUtc().millisecondsSinceEpoch;

  Future<ModelBusinessPlanWindow> fetchPlanWindow({
    required DateTime before,
    bool seekOlder = false,
  }) async {
    final data = await RepositoryBusinessPlanReads(
      supabase,
    ).planWindow(before: before, seekOlder: seekOlder);
    final rows = (data['rows'] as List? ?? const [])
        .map((row) => Map<String, dynamic>.from(row as Map))
        .map(_planSummaryFromJson)
        .toList(growable: false);
    final nextBefore = tryParseDateTimeValue(
      data['next_before'],
      toLocal: true,
    );
    if (nextBefore == null) {
      throw const FormatException('Invalid business plan cursor');
    }
    return ModelBusinessPlanWindow(
      plans: rows,
      nextBefore: nextBefore,
      hasMore: data['has_more'] == true,
    );
  }

  ModelBusinessPlan _planSummaryFromJson(Map<String, dynamic> row) =>
      ModelBusinessPlan(
        id: row[Fields.id],
        title: row['title'],
        createdAt:
            tryParseDateTimeValue(row[Fields.createdAt]) ?? DateTime.now(),
        status: parseStringValue(row['status'], fallback: 'not_started'),
        sections: const [],
      );

  Future<ModelBusinessPlan> fetchPlanDetail({required String planId}) async {
    try {
      final data = await supabase.rpc(
        'get_business_plan_detail',
        params: {'p_plan_id': planId},
      );

      return ModelBusinessPlan(
        id: data[Fields.id],
        title: data['title'],
        createdAt:
            tryParseDateTimeValue(data[Fields.createdAt]) ?? DateTime.now(),
        status: parseStringValue(data['status'], fallback: 'not_started'),
        sections: (data['sections'] as List)
            .map(
              (s) => ModelPlanSection(
                id: s[Fields.id],
                title: s['title'],
                sortOrder: s['sort_order'],
                questions: (s['questions'] as List)
                    .map(
                      (q) => ModelPlanQuestion(
                        id: q[Fields.id],
                        prompt: q['prompt'],
                        answer: q['answer'] ?? '',
                        sortOrder: q['sort_order'],
                      ),
                    )
                    .toList(),
              ),
            )
            .toList(),
      );
    } on Exception catch (exception) {
      logger.e(exception);
      rethrow;
    }
  }

  Future<void> updatePlanStatus({
    required String planId,
    required String status,
  }) async {
    await supabase
        .from(TableNames.businessPlan)
        .update({'status': status})
        .eq(Fields.id, planId);
  }

  Future<bool> hasPlansBefore({
    required String user,
    required DateTime before,
  }) async {
    _requireCurrentBusinessPlanUser(user);
    final cached = _cachedPlanWindow;
    if (cached != null && _sameInstant(cached.nextBefore, before)) {
      return cached.hasMore;
    }
    final window = await fetchPlanWindow(before: before, seekOlder: true);
    _cachePlanWindow(window, requestBefore: before, isNextPage: true);
    return window.plans.isNotEmpty;
  }

  Future<DateTime?> latestPlanDateBefore({
    required String user,
    required DateTime before,
  }) async {
    _requireCurrentBusinessPlanUser(user);
    var window = _cachedPlanWindow;
    if (!_cachedPlanWindowIsNextPage ||
        !_sameInstant(_cachedPlanWindowRequestBefore, before)) {
      window = await fetchPlanWindow(before: before, seekOlder: true);
      _cachePlanWindow(window, requestBefore: before, isNextPage: true);
    }
    return window?.plans.firstOrNull?.createdAt;
  }
}

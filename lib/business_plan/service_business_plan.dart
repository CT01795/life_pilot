import 'dart:core';

import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_plan_question.dart';
import 'package:life_pilot/business_plan/model_plan_section.dart';
import 'package:life_pilot/business_plan/model_plan_template.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:uuid/uuid.dart';

class ServiceBusinessPlan {
  // 1️⃣ 拉模板清單（給使用者選）
  Future<List<ModelPlanTemplate>> fetchTemplates() async {
    try {
      final res = await supabase
          .from(TableNames.businessPlanTemplate)
          .select()
          .eq(Fields.isValid, true)
          .order(Fields.createdAt, ascending: true);

      return (res as List)
          .map((e) => ModelPlanTemplate(
                id: e[Fields.id],
                title: e['title'],
                description: e['description'] ?? '',
              ))
          .toList();
    } on Exception catch (exception) {
      logger.e(exception);
      return [];
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
    List<String> sectionIdList = [];
    try {
      // 1. 查詢
      final exist = await supabase
          .from(TableNames.businessPlan)
          .select()
          .eq(Fields.createdBy, user)
          .eq('title', title)
          .maybeSingle();

      if (exist != null) {
        if (exist[Fields.isValid] == false) {
          await supabase
              .from(TableNames.businessPlan)
              .update({Fields.isValid: true}).eq(Fields.id, exist[Fields.id]);
        } else {
          throw Exception('Plan name already exists');
        }
      } else {
        await supabase.from(TableNames.businessPlan).insert({
          Fields.id: planId,
          'title': title,
          'template_id': templateId,
          Fields.createdBy: user,
          Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
          Fields.isValid: true,
        });
      }

      // 2️⃣ 取得模板 sections
      List responseSectionsTemplate = await supabase
          .from(TableNames.businessPlanTemplateSection)
          .select()
          .eq('plan_id', templateId)
          .order('sort_order', ascending: true);

      int i = 0;
      for (final s in responseSectionsTemplate) {
        sectionIdList.add(const Uuid().v4());

        // 3️⃣ 建立 section
        await supabase.from(TableNames.businessPlanSection).insert({
          Fields.id: sectionIdList[i],
          'plan_id': planId,
          'title': s['title'],
          'sort_order': s['sort_order'],
        });

        // 4️⃣ 建立題目
        List responseQuestionsTemplate = await supabase
            .from(TableNames.businessPlanTemplateQuestion)
            .select()
            .eq('section_id', s[Fields.id])
            .order('sort_order', ascending: true);

        final questionRows = responseQuestionsTemplate.map((q) {
          return {
            Fields.id: const Uuid().v4(),
            'section_id': sectionIdList[i],
            'prompt': q['prompt'],
            'sort_order': q['sort_order'],
          };
        }).toList();

        await supabase
            .from(TableNames.businessPlanQuestion)
            .insert(questionRows);
        i++;
      }
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
      await supabase.from(TableNames.businessPlan).update({
        'title': title,
      }).eq(Fields.id, planId);
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
      await supabase.from(TableNames.businessPlanAnswer).upsert(
        {
          'plan_id': planId,
          'section_id': sectionId,
          'question_id': questionId,
          'answer': answer,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'plan_id,section_id,question_id',
      );
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
      final res = await supabase
          .from(TableNames.businessPlan)
          .select()
          .eq(Fields.createdBy, user)
          .gte(Fields.createdAt, dateFrom.toUtc().toIso8601String())
          .lt(Fields.createdAt, dateTo.toUtc().toIso8601String())
          .order(Fields.createdAt, ascending: false);
      return (res as List).map((e) {
        return ModelBusinessPlan(
          id: e[Fields.id],
          title: e['title'],
          createdAt: DateTime.parse(e[Fields.createdAt]),
          status: e['status']?.toString() ?? 'not_started',
          sections: [], // 只用來顯示 list，實際 editor 再拉 detail
        );
      }).toList();
    } on Exception catch (exception) {
      logger.e(exception);
      rethrow;
    }
  }

  Future<ModelBusinessPlan> fetchPlanDetail({required String planId}) async {
    try {
      final data = await supabase.rpc(
        'get_business_plan_detail',
        params: {
          'p_plan_id': planId,
        },
      );

      return ModelBusinessPlan(
        id: data[Fields.id],
        title: data['title'],
        createdAt: DateTime.parse(data[Fields.createdAt]),
        status: data['status']?.toString() ?? 'not_started',
        sections: (data['sections'] as List)
            .map((s) => ModelPlanSection(
                  id: s[Fields.id],
                  title: s['title'],
                  sortOrder: s['sort_order'],
                  questions: (s['questions'] as List)
                      .map((q) => ModelPlanQuestion(
                            id: q[Fields.id],
                            prompt: q['prompt'],
                            answer: q['answer'] ?? '',
                            sortOrder: q['sort_order'],
                          ))
                      .toList(),
                ))
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
        .update({'status': status}).eq(Fields.id, planId);
  }

  Future<bool> hasPlansBefore({
    required String user,
    required DateTime before,
  }) async {
    final rows = await supabase
        .from(TableNames.businessPlan)
        .select(Fields.id)
        .eq(Fields.createdBy, user)
        .lt(Fields.createdAt, before.toUtc().toIso8601String())
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<DateTime?> latestPlanDateBefore({
    required String user,
    required DateTime before,
  }) async {
    final rows = await supabase
        .from(TableNames.businessPlan)
        .select(Fields.createdAt)
        .eq(Fields.createdBy, user)
        .lt(Fields.createdAt, before.toUtc().toIso8601String())
        .order(Fields.createdAt, ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first[Fields.createdAt]?.toString() ?? '')
        ?.toLocal();
  }
}

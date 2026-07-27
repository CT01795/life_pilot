import 'dart:core';

import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_plan_question.dart';
import 'package:life_pilot/business_plan/model_plan_section.dart';
import 'package:life_pilot/business_plan/model_plan_template.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ServiceBusinessPlan {
  final SupabaseClient _supabase = Supabase.instance.client;
  // 1️⃣ 拉模板清單（給使用者選）
  Future<List<ModelPlanTemplate>> fetchTemplates() async {
    try {
      final res = await _supabase
        .from(TableNames.businessPlanTemplate)
        .select()
        .eq('is_valid', true)
        .order('created_at', ascending: true);

      return (res as List)
          .map((e) => ModelPlanTemplate(
                id: e['id'],
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
      final exist = await _supabase
          .from(TableNames.businessPlan)
          .select()
          .eq('created_by', user)
          .eq('title', title)
          .maybeSingle();

      if (exist != null) {
        if (exist['is_valid'] == false) {
          await _supabase
              .from(TableNames.businessPlan)
              .update({'is_valid': true})
              .eq('id', exist['id']);
        } else {
          throw Exception('Plan name already exists');
        }
      } else {
        await _supabase.from(TableNames.businessPlan).insert({
          'id': planId,
          'title': title,
          'template_id': templateId,
          'created_by': user,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'is_valid': true,
        });
      }

      // 2️⃣ 取得模板 sections
      List responseSectionsTemplate = await _supabase
        .from(TableNames.businessPlanTemplateSection)
        .select()
        .eq('plan_id', templateId)
        .order('sort_order', ascending: true);

      int i = 0;
      for (final s in responseSectionsTemplate) {
        sectionIdList.add(const Uuid().v4());

        // 3️⃣ 建立 section
        await _supabase.from(TableNames.businessPlanSection).insert({
          'id': sectionIdList[i],
          'plan_id': planId,
          'title': s['title'],
          'sort_order': s['sort_order'],
        });

        // 4️⃣ 建立題目
        List responseQuestionsTemplate = await _supabase
          .from(TableNames.businessPlanTemplateQuestion)
          .select()
          .eq('section_id', s['id'])
          .order('sort_order', ascending: true);

        final questionRows = responseQuestionsTemplate.map((q) {
          return {
            'id': const Uuid().v4(),
            'section_id': sectionIdList[i],
            'prompt': q['prompt'],
            'sort_order': q['sort_order'],
          };
        }).toList();

        await _supabase
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
      await _supabase
          .from(TableNames.businessPlan)
          .update({
            'title': title,
          })
          .eq('id', planId);
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
      await _supabase
        .from(TableNames.businessPlanAnswer)
        .upsert(
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

  Future<List<ModelBusinessPlan>> fetchPlans({required String user}) async {
    try {
      final res = await _supabase
        .from(TableNames.businessPlan)
        .select()
        .eq('created_by', user)
        .order('created_at', ascending: true);
      return (res as List).map((e) {
        return ModelBusinessPlan(
          id: e['id'],
          title: e['title'],
          createdAt: DateTime.parse(e['created_at']),
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
      final data = await _supabase
        .rpc(
          'get_business_plan_detail',
          params: {
            'p_plan_id': planId,
          },
        );

      return ModelBusinessPlan(
        id: data['id'],
        title: data['title'],
        createdAt: DateTime.parse(data['created_at']),
        sections: (data['sections'] as List)
            .map((s) => ModelPlanSection(
                  id: s['id'],
                  title: s['title'],
                  sortOrder: s['sort_order'],
                  questions: (s['questions'] as List)
                      .map((q) => ModelPlanQuestion(
                            id: q['id'],
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
}

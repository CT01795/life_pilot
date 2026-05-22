import 'dart:core';

import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_plan_question.dart';
import 'package:life_pilot/business_plan/model_plan_section.dart';
import 'package:life_pilot/business_plan/model_plan_template.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ServiceBusinessPlan {
  final supabase = Supabase.instance.client;
  // 1️⃣ 拉模板清單（給使用者選）
  Future<List<ModelPlanTemplate>> fetchTemplates() async {
    try {
      /*
      final res = await api.post('business_plan/fetch_templates', {
        "table_name": TableNames.businessPlanTemplate
      });
      */
      final res = await apiSupabase.post('business_plan/fetch_templates',
          {"table_name": TableNames.businessPlanTemplate});

      if (res == null) return [];

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
    List<String> questionIdList = [];
    try {
      //await 
      api.post('business_plan/create_plan_from_template', {
        "table_name": TableNames.businessPlan,
        "user": user,
        "planId": planId,
        "title": title,
        "templateId": templateId,
      });

      // 2️⃣ 取得模板 sections
      List responseSectionsTemplate =
          await api.post('business_plan/get_sections_from_template', {
        "table_name": TableNames.businessPlanTemplateSection,
        "templateId": templateId,
      });
      int i = 0;
      int j = 0;
      for (final s in responseSectionsTemplate) {
        sectionIdList.add(const Uuid().v4());

        // 3️⃣ 建立 section
        await api.post('business_plan/insert_plan_sections', {
          "table_name": TableNames.businessPlanSection,
          "id": sectionIdList[i],
          "plan_id": planId,
          "title": s['title'],
          "sort_order": s['sort_order'],
        });

        // 4️⃣ 建立題目
        List responseQuestionsTemplate =
            await api.post('business_plan/get_questions_from_template', {
          "table_name": TableNames.businessPlanTemplateQuestion,
          "section_id": s['id'],
        });
        for (final q in responseQuestionsTemplate) {
          questionIdList.add(const Uuid().v4());
          await api.post('business_plan/insert_plan_questions', {
            "table_name": TableNames.businessPlanQuestion,
            "id": questionIdList[j],
            "section_id": sectionIdList[i],
            "prompt": q['prompt'],
            "sort_order": q['sort_order'],
          });
          j++;
        }
        i++;
      }
    } on Exception catch (exception, st) {
      logger.e(exception, stackTrace: st);
    }
    try {
      await apiSupabase.post('business_plan/create_plan_from_template', {
        "table_name": TableNames.businessPlan,
        "user": user,
        "planId": planId,
        "title": title,
        "templateId": templateId,
      });

      // 2️⃣ 取得模板 sections
      List responseSectionsTemplate =
          await api.post('business_plan/get_sections_from_template', {
        "table_name": TableNames.businessPlanTemplateSection,
        "templateId": templateId,
      });
      int i = 0;
      int j = 0;
      for (final s in responseSectionsTemplate) {
        sectionIdList.add(const Uuid().v4());
      
        // 3️⃣ 建立 section
        await apiSupabase.post('business_plan/insert_plan_sections', {
          "table_name": TableNames.businessPlanSection,
          "id": sectionIdList[i],
          "plan_id": planId,
          "title": s['title'],
          "sort_order": s['sort_order'],
        });

        // 4️⃣ 建立題目
        List responseQuestionsTemplate =
            await api.post('business_plan/get_questions_from_template', {
          "table_name": TableNames.businessPlanTemplateQuestion,
          "section_id": s['id'],
        });
        for (final q in responseQuestionsTemplate) {
          questionIdList.add(const Uuid().v4());
          await apiSupabase.post('business_plan/insert_plan_questions', {
            "table_name": TableNames.businessPlanQuestion,
            "id": questionIdList[j],
            "section_id": sectionIdList[i],
            "prompt": q['prompt'],
            "sort_order": q['sort_order'],
          });
          j++;
        }
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
      // 1️⃣ 建立 plan
      //await 
      api.post('business_plan/update_plan_title', {
        "table_name": TableNames.businessPlan,
        "planId": planId,
        "title": title,
      });
    } on Exception catch (exception) {
      logger.e(exception);
    }

    try {
      // 1️⃣ 建立 plan
      await apiSupabase.post('business_plan/update_plan_title', {
        "table_name": TableNames.businessPlan,
        "planId": planId,
        "title": title,
      });
    } on Exception catch (exception) {
      logger.e(exception);
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
      //await 
      api.post('business_plan/update_answer', {
        "table_name": TableNames.businessPlanAnswer,
        "planId": planId,
        "sectionId": sectionId,
        "questionId": questionId,
        "answer": answer,
      });
    } on Exception catch (exception) {
      logger.e(exception);
    }
    try {
      // 插入新的
      await apiSupabase.post('business_plan/update_answer', {
        "table_name": TableNames.businessPlanAnswer,
        "planId": planId,
        "sectionId": sectionId,
        "questionId": questionId,
        "answer": answer,
      });
    } on Exception catch (exception) {
      logger.e(exception);
      rethrow;
    }
  }

  Future<List<ModelBusinessPlan>> fetchPlans({required String user}) async {
    try {
      /*
      final res = await api.post('business_plan/fetch_plans', {
        "table_name": TableNames.businessPlan,
        "user": user,
      });
      */
      final res = await apiSupabase.post('business_plan/fetch_plans', {
        "table_name": TableNames.businessPlan,
        "user": user,
      });

      if (res.isEmpty) return [];

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
      /*
      final res = await api.post('business_plan/fetch_plan_detail', {
        "p_plan_id": planId,
      });
      */
      final res = await apiSupabase.post('business_plan/fetch_plan_detail', {
        "p_plan_id": planId,
      });

      final data = res as Map<String, dynamic>;

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

import 'package:life_pilot/models/business_plan/model_business_plan.dart';
import 'package:life_pilot/models/business_plan/model_plan_question.dart';
import 'package:life_pilot/models/business_plan/model_plan_section.dart';
import 'package:life_pilot/models/business_plan/model_plan_template.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ServiceBusinessPlan {
  final supabase = Supabase.instance.client;

  // 1️⃣ 拉模板清單（給使用者選）
  Future<List<ModelPlanTemplate>> fetchTemplates() async {
    final res = await supabase
        .from('business_plan_template')
        .select()
        .eq('is_active', true)
        .order('created_at');

    return (res as List)
        .map((e) => ModelPlanTemplate(
              id: e['id'],
              name: e['name'],
              description: e['description'] ?? '',
            ))
        .toList();
  }

  // 2️⃣ 依模板建立企劃書內容
  Future<List<ModelPlanSection>> buildSectionsFromTemplate(
    String templateId,
  ) async {
    final sectionsRes = await supabase
        .from('business_plan_template_section')
        .select('id, title')
        .eq('template_id', templateId)
        .order('sort_order');

    return Future.wait((sectionsRes as List).map((section) async {
      final questionsRes = await supabase
          .from('business_plan_template_question')
          .select('id, prompt')
          .eq('section_id', section['id'])
          .order('sort_order');

      return ModelPlanSection(
        id: const Uuid().v4(), // ⚠️ 新 plan 用新 id
        title: section['title'],
        questions: (questionsRes as List)
            .map((q) => ModelPlanQuestion(
                  id: const Uuid().v4(),
                  prompt: q['prompt'],
                ))
            .toList(),
      );
    }));
  }

  Future<void> insertBusinessPlan({
    required String user,
    required String planId,
    required String title,
    required String templateId,
  }) async {
    await supabase.from('business_plan').insert({
      'id': planId,
      'title': title,
      'template_id': templateId,
      'created_by': user,
    });
  }

  Future<void> upsertAnswer({
    required String planId,
    required int sectionOrder,
    required int questionOrder,
    required String sectionTitle,
    required String prompt,
    required String answer,
  }) async {
    await supabase.from('business_plan_answer').upsert({
      'plan_id': planId,
      'section_order': sectionOrder,
      'question_order': questionOrder,
      'section_title': sectionTitle,
      'prompt': prompt,
      'answer': answer,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<ModelBusinessPlan>> fetchPlans({required String user}) async {
    return [];
  }

}
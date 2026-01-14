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
    final res = await supabase
      .from('business_plan')
      .select()
      .eq('created_by', user)
      .order('created_at', ascending: false);

    if (res.isEmpty) return [];

    return (res as List).map((e) {
      return ModelBusinessPlan(
        id: e['id'],
        title: e['title'],
        createdAt: DateTime.parse(e['created_at']),
        sections: [], // 只用來顯示 list，實際 editor 再拉 detail
      );
    }).toList();
  }

  Future<ModelBusinessPlan> fetchPlanDetail({
    required String planId,
  }) async {
    // 1️⃣ Plan 本身
    final plan = await supabase
        .from('business_plan')
        .select()
        .eq('id', planId)
        .single();

    // 2️⃣ 用 template 重建 sections
    final sections =
        await buildSectionsFromTemplate(plan['template_id']);

    // 3️⃣ 拉答案
    final answers = await supabase
        .from('business_plan_answer')
        .select()
        .eq('plan_id', planId);

    // 4️⃣ 填答案回 sections
    for (final a in answers) {
      final s = a['section_order'];
      final q = a['question_order'];

      sections[s] = sections[s].copyWith(
        questions: sections[s].questions
          ..[q] = sections[s]
              .questions[q]
              .copyWith(answer: a['answer']),
      );
    }

    return ModelBusinessPlan(
      id: planId,
      title: plan['title'],
      createdAt: DateTime.parse(plan['created_at']),
      sections: sections,
    );
  }
}
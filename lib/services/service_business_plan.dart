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
  /// 建立企劃書
  Future<void> createPlanFromTemplate({
    required String user,
    required String planId,
    required String title,
    required String templateId,
  }) async {
    // 1️⃣ 建立 plan
    await supabase.from('business_plan').insert({
      'id': planId,
      'title': title,
      'template_id': templateId,
      'created_by': user,
    });

    // 2️⃣ 取得模板 sections
    final sectionsRes = await supabase
        .from('business_plan_template_section')
        .select('id, title, sort_order')
        .eq('template_id', templateId)
        .order('sort_order', ascending: true);

    for (final s in sectionsRes) {
      final sectionId = const Uuid().v4();

      // 3️⃣ 建立 section
      await supabase.from('business_plan_section').insert({
        'id': sectionId,
        'plan_id': planId,
        'title': s['title'],
        'sort_order': s['sort_order'],
      });

      // 4️⃣ 建立題目
      final questionsRes = await supabase
          .from('business_plan_template_question')
          .select('id, prompt, sort_order')
          .eq('section_id', s['id'])
          .order('sort_order', ascending: true);

      for (final q in questionsRes) {
        final questionId = const Uuid().v4();
        await supabase.from('business_plan_question').insert({
          'id': questionId,
          'section_id': sectionId,
          'prompt': q['prompt'],
          'sort_order': q['sort_order'],
        });
      }
    }
  }

  // 取得 Plan + Section + Question（帶答案）
  Future<List<ModelPlanSection>> fetchSectionsWithQuestions(String planId) async {
    final sectionsRes = await supabase
        .from('business_plan_section')
        .select('*')
        .eq('plan_id', planId)
        .order('sort_order', ascending: true);

    List<ModelPlanSection> sections = [];

    for (final s in sectionsRes) {
      final questionsRes = await supabase
          .from('business_plan_question')
          .select('*')
          .eq('section_id', s['id'])
          .order('sort_order', ascending: true);

      List<ModelPlanQuestion> questions = [];

      for (final q in questionsRes) {
        final answerRes = await supabase
            .from('business_plan_answer')
            .select('answer')
            .eq('plan_id', planId)
            .eq('question_id', q['id'])
            .maybeSingle();

        questions.add(ModelPlanQuestion(
          id: q['id'],
          prompt: q['prompt'],
          answer: answerRes?['answer'] ?? '',
          sortOrder: q['sort_order'],
        ));
      }

      sections.add(ModelPlanSection(
        id: s['id'],
        title: s['title'],
        sortOrder: s['sort_order'],
        questions: questions,
      ));
    }

    return sections;
  }
  
  Future<void> updatePlanTitle({
    required String planId,
    required String title,
  }) async {
    await supabase
        .from('business_plan')
        .update({'title': title})
        .eq('id', planId);
  }

  Future<void> upsertAnswer({
    required String planId,
    required String sectionId,
    required String questionId,
    required String answer,
  }) async {
    try{
      // 插入新的
      await supabase.from('business_plan_answer').insert({
        'id': const Uuid().v4(),
        'plan_id': planId,
        'section_id': sectionId,
        'question_id': questionId,
        'answer': answer,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
    on Exception{
        await supabase
      .from('business_plan_answer')
      .update({
        'answer': answer,
        'updated_at': DateTime.now().toIso8601String(),
      })
      .eq('plan_id', planId)
      .eq('section_id', sectionId)
      .eq('question_id', questionId);
      
    }
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

  Future<ModelBusinessPlan> fetchPlanDetail({required String planId}) async {
    final planRes = await supabase
        .from('business_plan')
        .select('*')
        .eq('id', planId)
        .maybeSingle();

    final sectionsRes = await supabase
        .from('business_plan_section')
        .select('*')
        .eq('plan_id', planId)
        .order('sort_order', ascending: true);

    List<ModelPlanSection> sections = [];

    for (final s in sectionsRes) {
      final questionsRes = await supabase
          .from('business_plan_question')
          .select('*')
          .eq('section_id', s['id'])
          .order('sort_order', ascending: true);

      List<ModelPlanQuestion> questions = [];

      for (final q in questionsRes) {
        final answerRes = await supabase
            .from('business_plan_answer')
            .select('answer')
            .eq('plan_id', planId)
            .eq('question_id', q['id'])
            .maybeSingle();

        questions.add(ModelPlanQuestion(
          id: q['id'],
          prompt: q['prompt'],
          answer: answerRes?['answer'] ?? '',
          sortOrder: q['sort_order'],
        ));
      }

      sections.add(ModelPlanSection(
        id: s['id'],
        title: s['title'],
        sortOrder: s['sort_order'],
        questions: questions,
      ));
    }

    return ModelBusinessPlan(
      id: planRes?['id'],
      title: planRes?['title'],
      createdAt: DateTime.parse(planRes?['created_at']),
      sections: sections,
    );
  }
}
import 'package:flutter/widgets.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/business_plan/model_business_plan.dart';
import 'package:life_pilot/models/business_plan/model_plan_question.dart';
import 'package:life_pilot/models/business_plan/model_plan_template.dart';
import 'package:life_pilot/services/service_business_plan.dart';
import 'package:uuid/uuid.dart';

class ControllerBusinessPlan extends ChangeNotifier {
  final ServiceBusinessPlan service;
  ControllerAuth? auth;

  ControllerBusinessPlan({required this.service, required this.auth,});

  List<ModelBusinessPlan> plans = [];
  ModelBusinessPlan? currentPlan;

  int sectionIndex = 0;
  int questionIndex = 0;

  bool isLoading = false;

  List<ModelPlanTemplate> templates = [];
  bool isTemplateLoading = false;

  Future<void> loadTemplates() async {
    isTemplateLoading = true;
    notifyListeners();
    templates = await service.fetchTemplates();
    isTemplateLoading = false;
    notifyListeners();
  }

  Future<void> createPlanFromTemplate({
    required String title,
    required String templateId,
  }) async {
    final planId = const Uuid().v4();

  // 1️⃣ 先在 DB 建立 Plan
    await service.insertBusinessPlan(
      planId: planId,
      title: title,
      templateId: templateId,
      user: auth?.currentAccount ?? AuthConstants.guest
    );

    // 2️⃣ 再用 template 生成 sections
    final sections =
        await service.buildSectionsFromTemplate(templateId);

    currentPlan = ModelBusinessPlan(
      id: const Uuid().v4(),
      title: title,
      createdAt: DateTime.now(),
      sections: sections,
    );

    sectionIndex = 0;
    questionIndex = 0;
    notifyListeners();
  }

  Future<void> commitCurrentAnswer(String answer) async {
    final section = currentPlan!.sections[sectionIndex];
    final questions = [...section.questions];

    questions[questionIndex] =
        questions[questionIndex].copyWith(answer: answer);

    currentPlan = currentPlan!.copyWith(
      sections: currentPlan!.sections
        ..[sectionIndex] = section.copyWith(questions: questions),
    );

    // 🔥 真正補上的地方
    await service.upsertAnswer(
      planId: currentPlan!.id,
      sectionOrder: sectionIndex,
      questionOrder: questionIndex,
      sectionTitle: section.title,
      prompt: questions[questionIndex].prompt,
      answer: answer,
    );

    notifyListeners();
  }

  Future<void> loadPlans() async {
    isLoading = true;
    notifyListeners();
    plans = await service.fetchPlans(user: auth?.currentAccount ?? AuthConstants.guest);
    isLoading = false;
    notifyListeners();
  }

  ModelPlanQuestion get currentQuestion =>
      currentPlan!.sections[sectionIndex].questions[questionIndex];

  bool next() {
    if (questionIndex <
        currentPlan!.sections[sectionIndex].questions.length - 1) {
      questionIndex++;
      notifyListeners();
      return true;
    }

    if (sectionIndex < currentPlan!.sections.length - 1) {
      sectionIndex++;
      questionIndex = 0;
      notifyListeners();
      return true;
    }

    return false;
  }

  bool previous() {
    if (questionIndex > 0) {
      questionIndex--;
      notifyListeners();
      return true;
    }

    if (sectionIndex > 0) {
      sectionIndex--;
      questionIndex =
          currentPlan!.sections[sectionIndex].questions.length - 1;
      notifyListeners();
      return true;
    }

    return false;
  }

  int get totalQuestions =>
    currentPlan!.sections.fold(
      0,
      (sum, s) => sum + s.questions.length,
    );

  int get currentQuestionNumber {
    int count = 0;
    for (int s = 0; s < sectionIndex; s++) {
      count += currentPlan!.sections[s].questions.length;
    }
    return count + questionIndex + 1;
  }

  double get progress =>
    currentQuestionNumber / totalQuestions;

  Future<void> resumePlan(String planId) async {
    isLoading = true;
    notifyListeners();

    currentPlan =
        await service.fetchPlanDetail(planId: planId);

    for (int s = 0; s < currentPlan!.sections.length; s++) {
      for (int q = 0;
          q < currentPlan!.sections[s].questions.length;
          q++) {
        if (currentPlan!.sections[s].questions[q].answer.isEmpty) {
          sectionIndex = s;
          questionIndex = q;
          isLoading = false;
          notifyListeners();
          return;
        }
      }
    }

    // 全部填完 → 停在最後
    sectionIndex = currentPlan!.sections.length - 1;
    questionIndex =
        currentPlan!.sections.last.questions.length - 1;

    isLoading = false;
    notifyListeners();
  }
}
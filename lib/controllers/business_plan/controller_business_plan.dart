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
  bool hasLoadedOnce = false;

  ControllerBusinessPlan({required this.service, required this.auth,});

  String? currentPlanId;

  void setCurrentPlanSummary(ModelBusinessPlan plan) {
    currentPlan = plan; // 只有 id / title
    currentPlanId = plan.id;
    // ❌ 不 notify（避免 preview 先 rebuild）
  }

  List<ModelBusinessPlan> plans = [];
  ModelBusinessPlan? currentPlan;

  int sectionIndex = 0;
  int questionIndex = 0;

  bool isPlansLoading = false;          // 列表用
  bool isCurrentPlanLoading = false;    // Preview / Editor 用

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
    // 1️⃣ 先建立 plan + section + question
    await service.createPlanFromTemplate(
      user: auth?.currentAccount ?? AuthConstants.guest,
      planId: planId,
      title: title,
      templateId: templateId,
    );

    // 2️⃣ 拉剛建立的 sections（帶題目）
    final sections = await service.fetchSectionsWithQuestions(planId);

    currentPlan = ModelBusinessPlan(
      id: planId, // 使用剛建立的 planId
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

    final newSections = [...currentPlan!.sections];
    newSections[sectionIndex] =
        section.copyWith(questions: questions);

    currentPlan = currentPlan!.copyWith(
      sections: newSections,
    );

    notifyListeners(); // UI 立即更新

    final question = questions[questionIndex];

    // 🔥 真正補上的地方
    await service.upsertAnswer(
      planId: currentPlan!.id,
      sectionId: section.id,
      questionId: question.id,
      answer: answer,
    );
  }

  Future<void> loadPlans() async {
    isPlansLoading = true;
    notifyListeners();
    try {
      plans = await service.fetchPlans(user: auth?.currentAccount ?? AuthConstants.guest);
    } catch (e, stack) {
      debugPrint('loadPlans error: $e');
      debugPrintStack(stackTrace: stack);
    } finally {
      isPlansLoading = false;
      notifyListeners(); // 🔥 關鍵
    }
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

  void jumpToQuestion({
    required int sectionIndex,
    required int questionIndex,
  }) {
    this.sectionIndex = sectionIndex;
    this.questionIndex = questionIndex;
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

  Future<void> loadPlanDetailIfNeeded(String planId) async {
    if (currentPlan?.id == planId &&
        currentPlan!.sections.isNotEmpty) {
      return;
    }

    isCurrentPlanLoading = true;
    try {
      currentPlan =
          await service.fetchPlanDetail(planId: planId);

      sectionIndex = 0;
      questionIndex = 0;

    } catch (e, stack) {
      debugPrint('resumePlan error: $e');
      debugPrintStack(stackTrace: stack);
    } finally {
      isCurrentPlanLoading = false;
      notifyListeners();
    }
  }
}
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_plan_question.dart';
import 'package:life_pilot/business_plan/model_plan_template.dart';
import 'package:life_pilot/business_plan/service_business_plan.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:uuid/uuid.dart';

class ControllerBusinessPlan extends ChangeNotifier {
  final ServiceBusinessPlan _service;
  ControllerAuth? auth;
  bool hasLoadedOnce = false;
  final Map<String, ModelBusinessPlan> _planCache = {};

  ControllerBusinessPlan({
    required ServiceBusinessPlan service,
    required this.auth,
  }) : _service = service;

  String? currentPlanId;
  ModelBusinessPlan? currentPlan;
  List<ModelBusinessPlan> plans = [];
  List<ModelPlanTemplate> templates = [];

  int sectionIndex = 0;
  int questionIndex = 0;

  bool isPlansLoading = false; // 列表用
  bool isTemplateLoading = false;

  // 單個 question 的 ValueNotifier
  final Map<String, ValueNotifier<String>> _answerNotifiers = {};

  // -------------------------
  // Public Methods
  // -------------------------
  void setCurrentPlanSummary(ModelBusinessPlan plan) {
    currentPlan = plan; // 只有 id / title
    currentPlanId = plan.id;
    _answerNotifiers.clear();
    notifyListeners();
  }

  ValueNotifier<String> answerNotifier(int section, int question) {
    final key = '$section-$question';
    return _answerNotifiers.putIfAbsent(
        key, () => ValueNotifier(planAnswerAt(section, question)));
  }

  void _syncAnswerNotifier(int section, int question, String value) {
    final key = '$section-$question';
    _answerNotifiers[key]?.value = value;
  }

  // 取得指定 question 的 answer
  String planAnswerAt(int sectionIndex, int questionIndex) {
    return currentPlan
            ?.sections[sectionIndex].questions[questionIndex].answer ??
        '';
  }

  ModelPlanQuestion get currentQuestion =>
      currentPlan!.sections[sectionIndex].questions[questionIndex];

  int get totalQuestions => currentPlan!.sections.fold(
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
      totalQuestions == 0 ? 0 : currentQuestionNumber / totalQuestions;

  // -------------------------
  // Navigation
  // -------------------------
  bool next() {
    if (questionIndex <
        currentPlan!.sections[sectionIndex].questions.length - 1) {
      questionIndex++;
      safeNotify();
      return true;
    }

    if (sectionIndex < currentPlan!.sections.length - 1) {
      sectionIndex++;
      questionIndex = 0;
      safeNotify();
      return true;
    }

    return false;
  }

  bool previous() {
    if (questionIndex > 0) {
      questionIndex--;
      safeNotify();
      return true;
    }

    if (sectionIndex > 0) {
      sectionIndex--;
      questionIndex = currentPlan!.sections[sectionIndex].questions.length - 1;
      safeNotify();
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
    safeNotify();
  }

  // -------------------------
  // Load Data
  // -------------------------
  Future<void> loadTemplates() async {
    isTemplateLoading = true;
    safeNotify();
    templates = await _service.fetchTemplates();
    isTemplateLoading = false;
    safeNotify();
  }

  Future<void> loadPlans() async {
    isPlansLoading = true;
    safeNotify();
    try {
      plans = await _service.fetchPlans(
          user: auth?.currentAccount ?? AuthConstants.guest);
    } finally {
      isPlansLoading = false;
      safeNotify();
    }
  }

  Future<void> loadPlanDetailIfNeeded(String inputPlanId) async {
    String planId = inputPlanId.trim();
    // 🚨 如果切換 plan，一定要 reset state
    if (currentPlanId != planId) {
      sectionIndex = 0;
      questionIndex = 0;
      currentPlan = null;
      currentPlanId = planId;
    }

    if (_planCache.containsKey(planId) &&
        _planCache[planId]!.sections.isNotEmpty) {
      currentPlan = _planCache[planId]?.copyWith();
      safeNotify();
      return;
    }
    safeNotify();

    try {
      final plan = await _service.fetchPlanDetail(planId: planId);
      currentPlan = plan;
      currentPlanId = planId;
      _answerNotifiers.clear();
      // 🔥 建議 copy 避免 reference污染
      _planCache[planId] = plan.copyWith();
    } finally {
      safeNotify();
    }
  }

  // -------------------------
  // Create & Update
  // -------------------------
  Future<void> createPlanFromTemplate({
    required String title,
    required String templateId,
  }) async {
    final planId = const Uuid().v4();
    // 1️⃣ 先建立 plan + section + question
    await _service.createPlanFromTemplate(
      user: auth?.currentAccount ?? AuthConstants.guest,
      planId: planId,
      title: title,
      templateId: templateId,
    );

    safeNotify();
    try {
      // 2️⃣ 拉剛建立的 sections（帶題目）
      final plan = await _service.fetchPlanDetail(planId: planId); // 👈 只打 RPC
      currentPlan = plan;
      _answerNotifiers.clear();
      _planCache[planId] = plan.copyWith();

      sectionIndex = 0;
      questionIndex = 0;
    } finally {
      safeNotify();
    }
  }

  Future<void> updateCurrentPlanTitle(
      ModelBusinessPlan oldPlan, String newTitle) async {
    currentPlan = (_planCache.containsKey(oldPlan.id)
            ? _planCache[oldPlan.id] as ModelBusinessPlan
            : oldPlan)
        .copyWith(title: newTitle);
    final index = plans.indexWhere((p) => p.id == oldPlan.id);
    if (index != -1) {
      plans[index] = plans[index].copyWith(title: newTitle);
    }

    safeNotify();

    // ✅ 更新 cache
    _planCache[oldPlan.id] = currentPlan!;

    // 2️⃣ 再存 DB
    try {
      await _service.updatePlanTitle(
        planId: oldPlan.id,
        title: newTitle,
      );
    } catch (e) {
      // ❌ 失敗就回滾
      currentPlan = currentPlan!.copyWith(title: oldPlan.title);
      if (index != -1) {
        plans[index] = plans[index].copyWith(title: oldPlan.title);
      }
      safeNotify();
    }
  }

  Future<void> commitCurrentAnswer(String answer) async {
    final section = currentPlan!.sections[sectionIndex];
    final question = section.questions[questionIndex];

    final notifier = answerNotifier(sectionIndex, questionIndex);
    notifier.value = answer;
    _syncAnswerNotifier(sectionIndex, questionIndex, answer);

    final questions = [...section.questions];

    questions[questionIndex] =
        questions[questionIndex].copyWith(answer: answer);

    final newSections = [...currentPlan!.sections];
    newSections[sectionIndex] = section.copyWith(questions: questions);

    currentPlan = currentPlan!.copyWith(
      sections: newSections,
    );
    _planCache[currentPlan!.id] = currentPlan!;

    try {
      await _service.upsertAnswer(
        planId: currentPlan!.id,
        sectionId: section.id,
        questionId: question.id,
        answer: answer,
      );
    } catch (e) {
      // 回滾到舊資料
      questions[questionIndex] =
          questions[questionIndex].copyWith(answer: question.answer);
      newSections[sectionIndex] = section.copyWith(questions: questions);
      currentPlan = currentPlan!.copyWith(sections: newSections);
      notifier.value = question.answer;
      safeNotify();
    }
  }

  void safeNotify() {
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }
}

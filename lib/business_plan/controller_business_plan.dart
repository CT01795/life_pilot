import 'package:flutter/widgets.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_plan_question.dart';
import 'package:life_pilot/business_plan/model_plan_template.dart';
import 'package:life_pilot/business_plan/service_business_plan.dart';
import 'package:uuid/uuid.dart';

class ControllerBusinessPlan extends ChangeNotifier {
  final ServiceBusinessPlan _service;
  ControllerAuth? auth;
  bool hasLoadedOnce = false;
  final Map<String, ModelBusinessPlan> _planCache = {};

  ControllerBusinessPlan({
    required ServiceBusinessPlan service,
    required this.auth,
  }): _service = service;

  String? currentPlanId;
  ModelBusinessPlan? currentPlan;
  List<ModelBusinessPlan> plans = [];
  List<ModelPlanTemplate> templates = [];

  int sectionIndex = 0;
  int questionIndex = 0;

  bool isPlansLoading = false; // 列表用
  bool isCurrentPlanLoading = false; // Preview / Editor 用
  bool isTemplateLoading = false;

  String? _loadingPlanId;

  // 單個 question 的 ValueNotifier
  final Map<String, ValueNotifier<String>> _answerNotifiers = {};

  // -------------------------
  // Public Methods
  // -------------------------
  void setCurrentPlanSummary(ModelBusinessPlan plan) {
    currentPlan = plan; // 只有 id / title
    currentPlanId = plan.id;
    // ❌ 不 notify（避免 preview 先 rebuild）
  }

  ValueNotifier<String> answerNotifier(int section, int question) {
    final key = '$section-$question';
    return _answerNotifiers.putIfAbsent(
        key, () => ValueNotifier(planAnswerAt(section, question)));
  }

  // 取得指定 question 的 answer
  String planAnswerAt(int sectionIndex, int questionIndex) {
    return currentPlan
            ?.sections[sectionIndex].questions[questionIndex].answer ??
        '';
  }

  ModelPlanQuestion get currentQuestion =>
      currentPlan!.sections[sectionIndex].questions[questionIndex];

  int get totalQuestions => currentPlan!.sections.fold(0, (sum, s) => sum + s.questions.length,);

  int get currentQuestionNumber {
    int count = 0;
    for (int s = 0; s < sectionIndex; s++) {
      count += currentPlan!.sections[s].questions.length;
    }
    return count + questionIndex + 1;
  }

  double get progress => totalQuestions == 0 ? 0 : currentQuestionNumber / totalQuestions;

  // -------------------------
  // Navigation
  // -------------------------
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
      questionIndex = currentPlan!.sections[sectionIndex].questions.length - 1;
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

  // -------------------------
  // Load Data
  // -------------------------
  Future<void> loadTemplates() async {
    isTemplateLoading = true;
    notifyListeners();
    templates = await _service.fetchTemplates();
    isTemplateLoading = false;
    notifyListeners();
  }

  Future<void> loadPlans() async {
    isPlansLoading = true;
    notifyListeners();
    try {
      plans = await _service.fetchPlans(
          user: auth?.currentAccount ?? AuthConstants.guest);
    } catch (e, stack) {
      debugPrint('loadPlans error: $e');
      debugPrintStack(stackTrace: stack);
    } finally {
      isPlansLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPlanDetailIfNeeded(String planId) async {
    if (isCurrentPlanLoading && _loadingPlanId == planId) return; // 🔒 關鍵
    // 先從 cache 讀
    if (_planCache.containsKey(planId)) {
      // 如果 currentPlan 不是同一個 plan 或 sections 是空的，才 assign
      if (currentPlan?.id != planId || currentPlan!.sections.isEmpty) {
        currentPlan = _planCache[planId];
        sectionIndex = 0;
        questionIndex = 0;
        notifyListeners();
      }
      return; // 不再抓 API
    }

    _loadingPlanId = planId;
    isCurrentPlanLoading = true;
    notifyListeners();
    try {
      // 2️⃣ 先建立「只有 id / title，sections 空」
      final summary = currentPlan;
      if (summary == null) return;

      currentPlan = summary.copyWith(sections: []);
      notifyListeners(); // 👉 UI 立刻顯示 Loading sections...

      // 2️⃣ 先抓第一個 section
      final firstSections =
          await _service.fetchSectionsWithQuestions(planId, limit: 1);
      currentPlan = currentPlan!.copyWith(sections: firstSections);
      notifyListeners();

      // 3️⃣ 背景抓剩下的 sections
      await _service.fetchSectionsWithQuestions(planId, limit: null)
        .then((restSections) {
        final allSections = [...restSections];
        currentPlan = currentPlan!.copyWith(sections: allSections);
        _planCache[planId] = currentPlan!;
        notifyListeners();
      });
      sectionIndex = 0;
      questionIndex = 0;
    } catch (e, stack) {
      debugPrint('loadPlanDetailIfNeeded error: $e');
      debugPrintStack(stackTrace: stack);
    } finally {
      _loadingPlanId = null;
      isCurrentPlanLoading = false;
      notifyListeners();
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

    // 2️⃣ 拉剛建立的 sections（帶題目）
    final sections = await _service.fetchSectionsWithQuestions(planId, limit: null);

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

  Future<void> updateCurrentPlanTitle(String newTitle) async {
    if (currentPlan == null) return;

    final oldPlan = currentPlan!;
    currentPlan = oldPlan.copyWith(
      title: newTitle,
      sections: oldPlan.sections
    );

    final index = plans.indexWhere((p) => p.id == oldPlan.id);
    if (index != -1) {
      plans[index] = plans[index].copyWith(title: newTitle);
    }

    notifyListeners();

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
      notifyListeners();
    }
  }

  Future<void> commitCurrentAnswer(String answer) async {
    final section = currentPlan!.sections[sectionIndex];
    final question = section.questions[questionIndex];

    final notifier = answerNotifier(sectionIndex, questionIndex);
    notifier.value = answer;

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
    } catch (e, stack) {
      debugPrint('commitCurrentAnswer error: $e');
      debugPrintStack(stackTrace: stack);

      // 回滾到舊資料
      questions[questionIndex] =
          questions[questionIndex].copyWith(answer: question.answer);
      newSections[sectionIndex] = section.copyWith(questions: questions);
      currentPlan = currentPlan!.copyWith(sections: newSections);
      notifier.value = question.answer;
      notifyListeners();
    }
  }
}

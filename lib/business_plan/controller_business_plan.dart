import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_business_plan_list.dart';
import 'package:life_pilot/business_plan/model_plan_answers.dart';
import 'package:life_pilot/business_plan/model_plan_question.dart';
import 'package:life_pilot/business_plan/model_plan_template.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/business_plan/service_business_plan.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:uuid/uuid.dart';
import 'package:life_pilot/utils/text_normalization.dart';

class ControllerBusinessPlan extends SafeChangeNotifier {
  final ServiceBusinessPlan _service;
  ControllerAuth? auth;
  String? _accountKey;
  int _accountGeneration = 0;
  bool hasLoadedOnce = false;
  final Map<String, ModelBusinessPlan> _planCache = {};
  final Set<String> _loadedPlanDetails = {};
  final Map<String, Future<ModelBusinessPlan>> _detailRequests = {};
  final _answerSaves = <(String, String, String), _PlanAnswerSaveQueue>{};
  int _detailSelectionRevision = 0;
  bool isPlanDetailLoading = false;
  Object? planDetailError;
  bool isCreatingPlan = false;

  ControllerBusinessPlan({
    required ServiceBusinessPlan service,
    required this.auth,
  }) : _service = service,
       _accountKey = normalizeText(auth?.currentAccount);

  String? currentPlanId;
  ModelBusinessPlan? currentPlan;
  List<ModelBusinessPlan> plans = [];
  List<ModelPlanTemplate> templates = [];

  int sectionIndex = 0;
  int questionIndex = 0;

  bool isPlansLoading = false; // 列表用
  Object? plansLoadError;
  bool isCheckingPlanHistory = false;
  Object? planHistoryError;
  Object? loadMorePlansError;
  int _planListRevision = 0;
  bool isTemplateLoading = false;
  Object? templateLoadError;
  bool isLoadingMorePlans = false;
  bool hasMorePlans = false;
  DateTime? _plansStartDate;
  final Set<String> selectedStatuses = {'in_progress', 'not_started'};

  // 單個 question 的 ValueNotifier
  final Map<String, ValueNotifier<String>> _answerNotifiers = {};

  // -------------------------
  // Public Methods
  // -------------------------
  void updateAuth(ControllerAuth nextAuth, {bool notify = true}) {
    final nextAccount = normalizeText(nextAuth.currentAccount);
    auth = nextAuth;
    if (_accountKey == nextAccount) return;
    _accountKey = nextAccount;
    _accountGeneration++;
    _planListRevision++;
    _detailSelectionRevision++;
    _loadedPlanDetails.clear();
    _detailRequests.clear();
    _answerSaves.clear();
    isPlanDetailLoading = false;
    planDetailError = null;
    isCreatingPlan = false;
    hasLoadedOnce = false;
    currentPlanId = null;
    currentPlan = null;
    plans = [];
    templates = [];
    templateLoadError = null;
    isTemplateLoading = false;
    _planCache.clear();
    _answerNotifiers.clear();
    sectionIndex = 0;
    questionIndex = 0;
    isPlansLoading = false;
    plansLoadError = null;
    isCheckingPlanHistory = false;
    planHistoryError = null;
    loadMorePlansError = null;
    isLoadingMorePlans = false;
    hasMorePlans = false;
    _plansStartDate = null;
    if (notify) safeNotify();
  }

  void setCurrentPlanSummary(ModelBusinessPlan plan) {
    _detailSelectionRevision++;
    isPlanDetailLoading = false;
    planDetailError = null;
    currentPlan = plan; // 只有 id / title
    currentPlanId = plan.id;
    _answerNotifiers.clear();
    notifyListeners();
  }

  ValueNotifier<String> answerNotifier(int section, int question) {
    final key = '$section-$question';
    return _answerNotifiers.putIfAbsent(
      key,
      () => ValueNotifier(planAnswerAt(section, question)),
    );
  }

  void _syncAnswerNotifier(int section, int question, String value) {
    final key = '$section-$question';
    _answerNotifiers[key]?.value = value;
  }

  // 取得指定 question 的 answer
  String planAnswerAt(int sectionIndex, int questionIndex) {
    return currentPlan
            ?.sections[sectionIndex]
            .questions[questionIndex]
            .answer ??
        '';
  }

  ModelPlanQuestion get currentQuestion =>
      currentPlan!.sections[sectionIndex].questions[questionIndex];

  int get totalQuestions =>
      currentPlan!.sections.fold(0, (sum, s) => sum + s.questions.length);

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

  void jumpToQuestion({required int sectionIndex, required int questionIndex}) {
    this.sectionIndex = sectionIndex;
    this.questionIndex = questionIndex;
    safeNotify();
  }

  // -------------------------
  // Load Data
  // -------------------------
  Future<void> loadTemplates() async {
    if (isTemplateLoading) return;
    final generation = _accountGeneration;
    isTemplateLoading = true;
    templateLoadError = null;
    safeNotify();
    try {
      final loadedTemplates = await _service.fetchTemplates();
      if (generation == _accountGeneration) templates = loadedTemplates;
    } catch (error) {
      if (generation == _accountGeneration) templateLoadError = error;
    } finally {
      if (generation == _accountGeneration) {
        isTemplateLoading = false;
        safeNotify();
      }
    }
  }

  Future<void> loadPlans() async {
    if (notifierDisposed ||
        isPlansLoading ||
        isCheckingPlanHistory ||
        isLoadingMorePlans) {
      return;
    }
    final generation = _accountGeneration;
    final revision = ++_planListRevision;
    final user = auth?.currentAccount ?? AuthConstants.guest;
    isPlansLoading = true;
    plansLoadError = null;
    planHistoryError = null;
    loadMorePlansError = null;
    safeNotify();
    try {
      final now = DateTime.now();
      final dateTo = DateTime(now.year, now.month, now.day + 1);
      final dateFrom = dateTo.subtract(const Duration(days: 360));
      if (!_isPlanListCurrent(generation, revision)) return;
      final loadedPlans = await _service.fetchPlans(
        user: user,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      if (!_isPlanListCurrent(generation, revision)) return;
      plans = loadedPlans;
      _plansStartDate = dateFrom;
      _sortAndDeduplicatePlans();
      // Publish useful content before waiting for the optional history probe.
      isPlansLoading = false;
      await _checkPlanHistory(user, dateFrom, generation, revision);
    } catch (error) {
      if (_isPlanListCurrent(generation, revision)) plansLoadError = error;
    } finally {
      if (_isPlanListCurrent(generation, revision)) {
        isPlansLoading = false;
        safeNotify();
      }
    }
  }

  bool _isPlanListCurrent(int generation, int revision) =>
      !notifierDisposed &&
      generation == _accountGeneration &&
      revision == _planListRevision;

  Future<void> _checkPlanHistory(
    String user,
    DateTime before,
    int generation,
    int revision,
  ) async {
    if (!_isPlanListCurrent(generation, revision)) return;
    isCheckingPlanHistory = true;
    planHistoryError = null;
    safeNotify();
    try {
      if (!_isPlanListCurrent(generation, revision)) return;
      final hasMore = await _service.hasPlansBefore(user: user, before: before);
      if (_isPlanListCurrent(generation, revision)) hasMorePlans = hasMore;
    } catch (error) {
      if (_isPlanListCurrent(generation, revision)) planHistoryError = error;
    } finally {
      if (_isPlanListCurrent(generation, revision)) {
        isCheckingPlanHistory = false;
        safeNotify();
      }
    }
  }

  Future<void> retryPlanHistory() async {
    final before = _plansStartDate;
    if (notifierDisposed ||
        before == null ||
        isPlansLoading ||
        isLoadingMorePlans ||
        isCheckingPlanHistory) {
      return;
    }
    await _checkPlanHistory(
      auth?.currentAccount ?? AuthConstants.guest,
      before,
      _accountGeneration,
      _planListRevision,
    );
  }

  List<ModelBusinessPlan> get visiblePlans =>
      plans.where((plan) => selectedStatuses.contains(plan.status)).toList();

  bool get hasPlanHistoryAction =>
      hasMorePlans ||
      isLoadingMorePlans ||
      isCheckingPlanHistory ||
      planHistoryError != null ||
      loadMorePlansError != null;

  void toggleStatus(String status) {
    selectedStatuses.contains(status)
        ? selectedStatuses.remove(status)
        : selectedStatuses.add(status);
    safeNotify();
  }

  Future<void> loadMorePlans() async {
    if (notifierDisposed ||
        isPlansLoading ||
        isCheckingPlanHistory ||
        isLoadingMorePlans ||
        !hasMorePlans ||
        _plansStartDate == null) {
      return;
    }
    final generation = _accountGeneration;
    final revision = _planListRevision;
    final before = _plansStartDate!;
    final user = auth?.currentAccount ?? AuthConstants.guest;
    isLoadingMorePlans = true;
    loadMorePlansError = null;
    planHistoryError = null;
    safeNotify();
    try {
      if (!_isPlanListCurrent(generation, revision)) return;
      final latestOlder = await _service.latestPlanDateBefore(
        user: user,
        before: before,
      );
      if (!_isPlanListCurrent(generation, revision)) return;
      if (latestOlder == null) {
        hasMorePlans = false;
        return;
      }
      final dateTo = DateTime(
        latestOlder.year,
        latestOlder.month,
        latestOlder.day + 1,
      );
      final dateFrom = dateTo.subtract(const Duration(days: 360));
      final loadedPlans = await _service.fetchPlans(
        user: user,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      if (!_isPlanListCurrent(generation, revision)) return;
      plans = [...plans, ...loadedPlans];
      // Advance only after a successful page read, so failures can retry the
      // same date window without skipping older records.
      _plansStartDate = dateFrom;
      _sortAndDeduplicatePlans();
      isLoadingMorePlans = false;
      await _checkPlanHistory(user, dateFrom, generation, revision);
    } catch (error) {
      if (_isPlanListCurrent(generation, revision)) loadMorePlansError = error;
    } finally {
      if (_isPlanListCurrent(generation, revision)) {
        isLoadingMorePlans = false;
        safeNotify();
      }
    }
  }

  Future<void> updatePlanStatus(ModelBusinessPlan plan, String status) async {
    final index = plans.indexWhere((item) => item.id == plan.id);
    if (index < 0) return;
    final previous = plans[index];
    plans[index] = previous.copyWith(status: status);
    _sortAndDeduplicatePlans();
    safeNotify();
    try {
      await _service.updatePlanStatus(planId: plan.id, status: status);
    } catch (_) {
      final rollbackIndex = plans.indexWhere((item) => item.id == plan.id);
      if (rollbackIndex >= 0) plans[rollbackIndex] = previous;
      _sortAndDeduplicatePlans();
      safeNotify();
      rethrow;
    }
  }

  void _sortAndDeduplicatePlans() {
    plans = ModelBusinessPlanList.ordered(plans);
  }

  Future<void> loadPlanDetailIfNeeded(String inputPlanId) async {
    if (notifierDisposed) return;
    final planId = inputPlanId.trim();
    if (planId.isEmpty) return;
    final generation = _accountGeneration;
    final revision = ++_detailSelectionRevision;
    if (currentPlanId != planId) {
      sectionIndex = 0;
      questionIndex = 0;
      currentPlan = null;
      currentPlanId = planId;
    }
    planDetailError = null;
    final cached = _planCache[planId];
    if (_loadedPlanDetails.contains(planId) && cached != null) {
      currentPlan = cached.copyWith();
      isPlanDetailLoading = false;
      safeNotify();
      return;
    }
    isPlanDetailLoading = true;
    safeNotify();
    final request = _detailRequests.putIfAbsent(
      planId,
      () => Future<ModelBusinessPlan>.sync(
        () => _service.fetchPlanDetail(planId: planId),
      ),
    );
    try {
      final plan = await request;
      if (notifierDisposed || generation != _accountGeneration) return;
      _planCache[planId] = plan.copyWith();
      _loadedPlanDetails.add(planId);
      if (revision != _detailSelectionRevision || currentPlanId != planId) {
        return;
      }
      currentPlan = plan;
      _answerNotifiers.clear();
    } catch (error) {
      if (!notifierDisposed &&
          generation == _accountGeneration &&
          revision == _detailSelectionRevision) {
        planDetailError = error;
      }
    } finally {
      if (identical(_detailRequests[planId], request)) {
        _detailRequests.remove(planId);
      }
      if (!notifierDisposed &&
          generation == _accountGeneration &&
          revision == _detailSelectionRevision) {
        isPlanDetailLoading = false;
        safeNotify();
      }
    }
  }

  // -------------------------
  // Create & Update
  // -------------------------
  Future<bool> createPlanFromTemplate({
    required String title,
    required String templateId,
  }) async {
    if (notifierDisposed || isCreatingPlan) return false;
    if (title.trim().isEmpty) throw ArgumentError('Plan title is required');
    final generation = _accountGeneration;
    final user = auth?.currentAccount ?? AuthConstants.guest;
    final planId = const Uuid().v4();
    isCreatingPlan = true;
    _detailSelectionRevision++;
    isPlanDetailLoading = false;
    planDetailError = null;
    safeNotify();
    try {
      await _service.createPlanFromTemplate(
        user: user,
        planId: planId,
        title: title.trim(),
        templateId: templateId,
      );
      if (notifierDisposed || generation != _accountGeneration) return false;
      final plan = await _service.fetchPlanDetail(planId: planId);
      if (notifierDisposed || generation != _accountGeneration) return false;
      _detailSelectionRevision++;
      currentPlan = plan;
      currentPlanId = planId;
      _answerNotifiers.clear();
      _planCache[planId] = plan.copyWith();
      _loadedPlanDetails.add(planId);
      final firstQuestionSection = plan.sections.indexWhere(
        (section) => section.questions.isNotEmpty,
      );
      sectionIndex = firstQuestionSection < 0 ? 0 : firstQuestionSection;
      questionIndex = 0;
      // Publish the new summary without another list query on return.
      plans = [...plans, plan.copyWith(sections: [])];
      _sortAndDeduplicatePlans();
      return true;
    } catch (_) {
      if (notifierDisposed || generation != _accountGeneration) return false;
      rethrow;
    } finally {
      if (!notifierDisposed && generation == _accountGeneration) {
        isCreatingPlan = false;
        safeNotify();
      }
    }
  }

  Future<void> updateCurrentPlanTitle(
    ModelBusinessPlan oldPlan,
    String newTitle,
  ) async {
    currentPlan =
        (_planCache.containsKey(oldPlan.id)
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
      await _service.updatePlanTitle(planId: oldPlan.id, title: newTitle);
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
    final plan = currentPlan;
    if (notifierDisposed || plan == null) return;
    final section = plan.sections[sectionIndex];
    final question = section.questions[questionIndex];
    final key = (plan.id, section.id, question.id);
    if (question.answer == answer) {
      await _answerSaves[key]?.tail;
      return;
    }
    final generation = _accountGeneration;
    final queue = _answerSaves.putIfAbsent(
      key,
      () => _PlanAnswerSaveQueue(question.answer),
    );
    final revision = ++queue.revision;
    final notifier = answerNotifier(sectionIndex, questionIndex);
    currentPlan = ModelPlanAnswers.replace(
      plan,
      sectionId: section.id,
      questionId: question.id,
      answer: answer,
    );
    _planCache[plan.id] = currentPlan!;
    bool isActive() => !notifierDisposed && generation == _accountGeneration;
    // Serialize only this question; unrelated questions can save independently.
    final operation = queue.tail.then((_) async {
      if (!isActive()) return;
      try {
        await _service.upsertAnswer(
          planId: plan.id,
          sectionId: section.id,
          questionId: question.id,
          answer: answer,
        );
        if (isActive()) queue.confirmedAnswer = answer;
      } catch (_) {
        if (!isActive() || revision != queue.revision) return;
        final cached = _planCache[plan.id];
        if (cached != null) {
          _planCache[plan.id] = ModelPlanAnswers.replace(
            cached,
            sectionId: section.id,
            questionId: question.id,
            answer: queue.confirmedAnswer,
            expectedAnswer: answer,
          );
        }
        final active = currentPlan;
        if (active == null || active.id != plan.id) return;
        final restored = ModelPlanAnswers.replace(
          active,
          sectionId: section.id,
          questionId: question.id,
          answer: queue.confirmedAnswer,
          expectedAnswer: answer,
        );
        if (identical(restored, active)) return;
        currentPlan = restored;
        final s = restored.sections.indexWhere((item) => item.id == section.id);
        final q = restored.sections[s].questions.indexWhere(
          (item) => item.id == question.id,
        );
        _syncAnswerNotifier(s, q, queue.confirmedAnswer);
        safeNotify();
      }
    });
    queue.tail = operation;
    notifier.value = answer;
    try {
      await operation;
    } finally {
      if (identical(_answerSaves[key], queue) &&
          identical(queue.tail, operation)) {
        _answerSaves.remove(key);
      }
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

class _PlanAnswerSaveQueue {
  _PlanAnswerSaveQueue(this.confirmedAnswer);
  String confirmedAnswer;
  int revision = 0;
  Future<void> tail = Future<void>.value();
}

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:life_pilot/utils/widgets/widgets_load_error.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:life_pilot/business_plan/controller_business_plan.dart';
import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_plan_preview.dart';
import 'package:life_pilot/business_plan/model_plan_question.dart';
import 'package:life_pilot/business_plan/page_plan_editor.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:provider/provider.dart';

class PagePlanPreview extends StatefulWidget {
  const PagePlanPreview({super.key});

  @override
  State<PagePlanPreview> createState() => _PagePlanPreviewState();
}

class _PagePlanPreviewState extends State<PagePlanPreview> {
  bool editingTitle = false;
  final _titleKey = GlobalKey<_EditablePlanTitleState>();
  PlanPreviewIndex? _previewIndex;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = context.read<ControllerBusinessPlan>();
      final id = c.currentPlanId ?? c.currentPlan?.id;
      if (id != null) c.loadPlanDetailIfNeeded(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ControllerBusinessPlan>(
      builder: (_, controller, _) {
        final plan = controller.currentPlan;
        final loc = AppLocalizations.of(context)!;
        if (controller.isPlanDetailLoading ||
            controller.planDetailError != null ||
            plan == null) {
          _previewIndex = null;
          return Scaffold(
            appBar: AppBar(title: Text(loc.businessPlan)),
            body: controller.isPlanDetailLoading
                ? const Center(child: CircularProgressIndicator())
                : controller.planDetailError != null
                ? Center(
                    child: WidgetsLoadError(
                      onRetry: () {
                        final id = controller.currentPlanId;
                        if (id != null) controller.loadPlanDetailIfNeeded(id);
                      },
                    ),
                  )
                : Center(child: Text(loc.noData)),
          );
        }
        var preview = _previewIndex;
        if (preview == null || !preview.matches(plan)) {
          _previewIndex = preview = PlanPreviewIndex(plan);
        }
        final items = preview.items;
        return Scaffold(
          appBar: AppBar(
            title: EditablePlanTitle(
              key: _titleKey,
              editing: editingTitle,
              onSave: (value) {
                context.read<ControllerBusinessPlan>().updateCurrentPlanTitle(
                  plan,
                  value,
                );
              },
            ),
            actions: [
              IconButton(
                tooltip: editingTitle ? loc.save : loc.edit,
                icon: Icon(
                  editingTitle ? Icons.check : Icons.edit,
                  color: Colors.white,
                ),
                onPressed:
                    !plan.sections.any(
                      (section) => section.questions.isNotEmpty,
                    )
                    ? null
                    : () {
                        final c = context.read<ControllerBusinessPlan>();
                        // 先確保 current plan 與當前題目
                        c.jumpToQuestion(
                          sectionIndex: plan.sections.indexWhere(
                            (section) => section.questions.isNotEmpty,
                          ),
                          questionIndex: 0,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: c,
                              child: const PagePlanEditor(),
                            ),
                          ),
                        );
                      },
              ),
            ],
          ),
          body: plan.sections.isEmpty
              ? Center(child: Text(loc.noData))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    if (item is PlanSectionItem) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        margin: Insets.directionalT24B12,
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                      );
                    }

                    final q = item as PlanQuestionItem;
                    return _ExpandableQuestionTile(
                      sectionIndex: q.sectionIndex,
                      questionIndex: q.questionIndex,
                      question: q.question,
                    );
                  },
                ),
        );
      },
    );
  }
}

// ===== 單一 Question Tile 可展開 =====
class _ExpandableQuestionTile extends StatefulWidget {
  final int sectionIndex;
  final int questionIndex;
  final ModelPlanQuestion question;

  const _ExpandableQuestionTile({
    required this.sectionIndex,
    required this.questionIndex,
    required this.question,
  });

  @override
  State<_ExpandableQuestionTile> createState() =>
      _ExpandableQuestionTileState();
}

class _ExpandableQuestionTileState extends State<_ExpandableQuestionTile> {
  bool _expanded = false;

  String _shortenHtml(String html, int maxLength) {
    final text = html.replaceAll(RegExp(r'<[^>]*>', multiLine: true), '');
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.read<ControllerBusinessPlan>();
    final notifier = c.answerNotifier(
      widget.sectionIndex,
      widget.questionIndex,
    );
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: Insets.directionalB12,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (notifier.value.isEmpty) {
            // 空答案就直接進編輯頁
            c.jumpToQuestion(
              sectionIndex: widget.sectionIndex,
              questionIndex: widget.questionIndex,
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: context.read<ControllerBusinessPlan>(),
                  child: const PagePlanEditor(),
                ),
              ),
            );
            return;
          }

          setState(() {
            _expanded = !_expanded;
          });
        },
        onLongPress: () {
          // 長按直接進入編輯頁
          c.jumpToQuestion(
            sectionIndex: widget.sectionIndex,
            questionIndex: widget.questionIndex,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: context.read<ControllerBusinessPlan>(),
                child: const PagePlanEditor(),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ValueListenableBuilder<String>(
            valueListenable: notifier,
            builder: (_, answer, _) {
              final previewText = answer.isEmpty
                  ? loc.notFilled
                  : _shortenHtml(answer, 50);
              return _expanded ? Html(data: answer) : Text(previewText);
            },
          ),
        ),
      ),
    );
  }
}

class EditablePlanTitle extends StatefulWidget {
  final bool editing;
  final void Function(String value) onSave;
  const EditablePlanTitle({
    super.key,
    required this.editing,
    required this.onSave,
  });

  @override
  State<EditablePlanTitle> createState() => _EditablePlanTitleState();
}

class _EditablePlanTitleState extends State<EditablePlanTitle> {
  late TextEditingController controller;
  String get currentText => controller.text;

  @override
  void initState() {
    super.initState();
    final title =
        context.read<ControllerBusinessPlan>().currentPlan?.title ?? '';
    controller = TextEditingController(text: title);
  }

  @override
  Widget build(BuildContext context) {
    return Selector<ControllerBusinessPlan, ModelBusinessPlan?>(
      selector: (_, c) => c.currentPlan,
      builder: (_, plan, _) {
        if (plan == null) return const SizedBox();
        return Text(plan.title);
      },
    );
  }
}

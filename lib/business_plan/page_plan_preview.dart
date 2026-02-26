import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:life_pilot/business_plan/controller_business_plan.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_plan_preview.dart';
import 'package:life_pilot/business_plan/model_plan_question.dart';
import 'package:life_pilot/business_plan/page_plan_editor.dart';
import 'package:provider/provider.dart';

class PagePlanPreview extends StatefulWidget {
  const PagePlanPreview({super.key});

  @override
  State<PagePlanPreview> createState() => _PagePlanPreviewState();
}

class _PagePlanPreviewState extends State<PagePlanPreview> {
  bool editingTitle = false;
  final _titleKey = GlobalKey<_EditablePlanTitleState>();

  @override
  void initState() {
    super.initState();

    final c = context.read<ControllerBusinessPlan>();
    // 當前 plan summary 已經在 c.currentPlan
    // 如果 sections 為空，就去抓詳細內容
    if (c.currentPlan?.sections.isEmpty ?? true) {
      c.loadPlanDetailIfNeeded(c.currentPlan!.id);
    }
  }

  // 1️⃣ 計算總 item 數量
  int _totalItemCount(ModelBusinessPlan plan) {
    if (plan.sections.isEmpty) return 1; // skeleton
    int count = 0;
    for (var s in plan.sections) {
      count += 1; // section title
      count += s.questions.length; // questions
    }
    return count;
  }

  // 2️⃣ 依 index 取得 item
  PlanPreviewItem _itemAtIndex(ModelBusinessPlan plan, int index) {
    if (plan.sections.isEmpty) return PlanSectionItem('Loading sections...');

    int counter = 0;
    for (int s = 0; s < plan.sections.length; s++) {
      if (counter == index) return PlanSectionItem(plan.sections[s].title);
      counter++;
      for (int q = 0; q < plan.sections[s].questions.length; q++) {
        if (counter == index) {
          return PlanQuestionItem(s, q, plan.sections[s].questions[q]);
        }
        counter++;
      }
    }
    return PlanSectionItem('Loading...'); // fallback
  }

  @override
  Widget build(BuildContext context) {
    return Selector<ControllerBusinessPlan, ModelBusinessPlan?>(
      selector: (_, c) => c.currentPlan,
      builder: (_, plan, __) {
        if (plan == null) return const CircularProgressIndicator();
        return Scaffold(
          appBar: AppBar(
            title: EditablePlanTitle(
              key: _titleKey,
              editing: editingTitle,
              onSave: (value) {
                context.read<ControllerBusinessPlan>()
                    .updateCurrentPlanTitle(value);
              },
            ),
            actions: [
              IconButton(
                icon: Icon(editingTitle ? Icons.check : Icons.edit, color: Colors.white,),
                onPressed: () {
                  final c = context.read<ControllerBusinessPlan>();
                  // 先確保 current plan 與當前題目
                  c.jumpToQuestion(sectionIndex: 0, questionIndex: 0);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PagePlanEditor()),
                  );
                },
              ),
            ],
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _totalItemCount(plan),
            itemBuilder: (_, i) {
              final item = _itemAtIndex(plan, i);
              if (item is PlanSectionItem) {
                return Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
              // 如果 sections 尚未 load → skeleton tile
              if (plan.sections.isEmpty) {
                return Container(
                  margin: Insets.directionalB12,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }

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
    final c = context.read<ControllerBusinessPlan>();
    final notifier = c.answerNotifier(widget.sectionIndex, widget.questionIndex);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
              MaterialPageRoute(builder: (_) => const PagePlanEditor()),
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
            MaterialPageRoute(builder: (_) => const PagePlanEditor()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ValueListenableBuilder<String>(
            valueListenable: notifier,
            builder: (_, answer, __) {
              final previewText = answer.isEmpty
                  ? '（尚未填寫）'
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
    final title = context.read<ControllerBusinessPlan>().currentPlan?.title ?? '';
    controller = TextEditingController(text: title);
  }

  @override
  Widget build(BuildContext context) {
    return Selector<ControllerBusinessPlan, ModelBusinessPlan?>(
      selector: (_, c) => c.currentPlan,
      builder: (_, plan, __) {
        if (plan == null) return const SizedBox();
        return Text(plan.title);
      },
    );
  }
}
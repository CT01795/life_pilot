import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:life_pilot/controllers/business_plan/controller_business_plan.dart';
import 'package:life_pilot/models/business_plan/model_business_plan.dart';
import 'package:life_pilot/models/business_plan/model_plan_preview.dart';
import 'package:life_pilot/models/business_plan/model_plan_question.dart';
import 'package:life_pilot/pages/business_plan/page_plan_editor.dart';
import 'package:provider/provider.dart';

class PagePlanPreview extends StatefulWidget {
  const PagePlanPreview({super.key});

  @override
  State<PagePlanPreview> createState() => _PagePlanPreviewState();
}

class _PagePlanPreviewState extends State<PagePlanPreview> {
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

  @override
  Widget build(BuildContext context) {
    return Selector<ControllerBusinessPlan, _PreviewState>(
      selector: (_, c) => _PreviewState(
        plan: c.currentPlan,
        isLoading: c.isCurrentPlanLoading,
      ),
      builder: (_, state, __) {
        final plan = state.plan;

        // 還沒 summary
        if (plan == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final items = <PlanPreviewItem>[];

        if (plan.sections.isEmpty) {
          // 尚未抓到詳細資料 → 顯示 skeleton
          items.add(PlanSectionItem('Loading sections...'));
        } else {
          for (int s = 0; s < plan.sections.length; s++) {
            items.add(PlanSectionItem(plan.sections[s].title));
            for (int q = 0; q < plan.sections[s].questions.length; q++) {
              items.add(
                PlanQuestionItem(s, q, plan.sections[s].questions[q]),
              );
            }
          }
        }

        return Scaffold(
          appBar: AppBar(title: Text(plan.title)),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];

              if (item is PlanSectionItem) {
                return Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 12, top: 24),
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
                  margin: const EdgeInsets.only(bottom: 12),
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

  @override
  Widget build(BuildContext context) {
    final c = context.read<ControllerBusinessPlan>();

    // 預覽文字（前 50 字）
    String previewText = widget.question.answer.isEmpty
        ? '（尚未填寫）'
        : _shortenHtml(widget.question.answer, 50);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (widget.question.answer.isEmpty) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _expanded
                  ? Html(data: widget.question.answer)
                  : Text(
                      previewText,
                      style: widget.question.answer.isEmpty
                          ? TextStyle(color: Colors.grey.shade600)
                          : null,
                    ),
              if (!_expanded && widget.question.answer.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '點擊展開全文或長按編輯',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortenHtml(String html, int maxLength) {
    final text = html.replaceAll(RegExp(r'<[^>]*>', multiLine: true), '');
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

// ===== Selector 用的小型 state =====
class _PreviewState {
  final ModelBusinessPlan? plan;
  final bool isLoading;

  const _PreviewState({
    required this.plan,
    required this.isLoading,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PreviewState &&
          other.plan == plan &&
          other.isLoading == isLoading;

  @override
  int get hashCode => Object.hash(plan, isLoading);
}
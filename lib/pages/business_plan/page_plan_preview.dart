import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:life_pilot/controllers/business_plan/controller_business_plan.dart';
import 'package:life_pilot/models/business_plan/model_business_plan.dart';
import 'package:life_pilot/models/business_plan/model_plan_preview.dart';
import 'package:life_pilot/models/business_plan/model_plan_question.dart';
import 'package:life_pilot/pages/business_plan/page_plan_editor.dart';
import 'package:provider/provider.dart';

class PagePlanPreview extends StatelessWidget {
  const PagePlanPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<ControllerBusinessPlan, _PreviewState>(
      selector: (_, c) => _PreviewState(
        plan: c.currentPlan,
        isLoading: c.isCurrentPlanLoading,
      ),
      builder: (_, state, __) {
        if (state.isLoading || state.plan == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final plan = state.plan!;

        final items = <PlanPreviewItem>[];

        for (int s = 0; s < plan.sections.length; s++) {
          items.add(PlanSectionItem(plan.sections[s].title));
          for (int q = 0; q < plan.sections[s].questions.length; q++) {
            items.add(
              PlanQuestionItem(
                s,
                q,
                plan.sections[s].questions[q],
              ),
            );
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(plan.title),
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];

              if (item is PlanSectionItem) {
                return Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }

              final q = item as PlanQuestionItem;
              return _QuestionTile(
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

// ===== 單一 Question Tile =====
class _QuestionTile extends StatelessWidget {
  final int sectionIndex;
  final int questionIndex;
  final ModelPlanQuestion question;

  const _QuestionTile({
    required this.sectionIndex,
    required this.questionIndex,
    required this.question,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.read<ControllerBusinessPlan>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          c.jumpToQuestion(
            sectionIndex: sectionIndex,
            questionIndex: questionIndex,
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PagePlanEditor(),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: question.answer.isEmpty
              ? const Text('（尚未填寫）')
              : Html(data: question.answer),
        ),
      ),
    );
  }
}
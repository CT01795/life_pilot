import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:life_pilot/controllers/business_plan/controller_business_plan.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/pages/business_plan/page_plan_editor.dart';
import 'package:provider/provider.dart';

class PagePlanPreview extends StatelessWidget {
  const PagePlanPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ControllerBusinessPlan>(builder: (_, c, __) {
      final plan = c.currentPlan!;
      return Scaffold(
        appBar: AppBar(title: Text(plan.title)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (int s = 0; s < plan.sections.length; s++) ...[
              Text(
                plan.sections[s].title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Gaps.h8,
              for (int q = 0; q < plan.sections[s].questions.length; q++) ...[
                InkWell(
                  onTap: () {
                    c.jumpToQuestion(
                      sectionIndex: s,
                      questionIndex: q,
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
                    child: plan.sections[s].questions[q].answer.isEmpty
                        ? const Text('（尚未填寫）')
                        : Html(
                            data: plan.sections[s].questions[q].answer,
                          ),
                  ),
                ),
                Gaps.h16,
              ],
            ],
          ],
        ),
      );
    });
  }
}

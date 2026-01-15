import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:life_pilot/controllers/business_plan/controller_business_plan.dart';
import 'package:life_pilot/core/const.dart';
import 'package:provider/provider.dart';

class PagePlanPreview extends StatelessWidget {
  const PagePlanPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final plan = context.read<ControllerBusinessPlan>().currentPlan!;

    return Scaffold(
      appBar: AppBar(title: Text(plan.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final section in plan.sections) ...[
            Text(
              section.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Gaps.h8,
            for (final q in section.questions) ...[
              Text(
                q.prompt,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Gaps.h8,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: q.answer.isEmpty
                    ? const Text('（尚未填寫）')
                    : Html(
                        data: q.answer, // 直接渲染 HTML
                      ),
              ),
              Gaps.h16,
            ],
          ]
        ],
      ),
    );
  }
}

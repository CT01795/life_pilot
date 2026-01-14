import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/business_plan/controller_business_plan.dart';
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
            const SizedBox(height: 12),
            for (final q in section.questions) ...[
              Text(
                q.prompt,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  q.answer.isEmpty ? '（尚未填寫）' : q.answer,
                  style: const TextStyle(height: 1.6),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ]
        ],
      ),
    );
  }
}

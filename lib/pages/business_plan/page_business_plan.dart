import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/business_plan/controller_business_plan.dart';
import 'package:life_pilot/models/business_plan/model_business_plan.dart';
import 'package:life_pilot/pages/business_plan/page_plan_editor.dart';
import 'package:life_pilot/pages/business_plan/page_plan_select_template.dart';
import 'package:provider/provider.dart';

class PageBusinessPlan extends StatefulWidget {
  const PageBusinessPlan({super.key});

  @override
  State<PageBusinessPlan> createState() => _PageBusinessPlanState();
}

class _PageBusinessPlanState extends State<PageBusinessPlan> {
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    context.read<ControllerBusinessPlan>().loadPlans();
    _inited = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Selector<ControllerBusinessPlan, bool>(
        selector: (_, c) => c.isLoading,
        builder: (_, isLoading, __) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Selector<ControllerBusinessPlan, List<ModelBusinessPlan>>(
            selector: (_, c) => c.plans,
            builder: (_, plans, __) {
              if (plans.isEmpty) {
                return const Center(child: Text('No plans yet'));
              }

              return ListView.builder(
                itemCount: plans.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text('Plan ${i+1}: ${plans[i].title}'),
                  onTap: () async {
                    await context
                        .read<ControllerBusinessPlan>()
                        .resumePlan(plans[i].id);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PagePlanEditor(),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PagePlanSelectTemplate(),
            ),
          );
        },
        child: const Icon(Icons.add, size: 50),
      ),
    );
  }
}
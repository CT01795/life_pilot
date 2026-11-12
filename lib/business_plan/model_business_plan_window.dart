import 'package:life_pilot/business_plan/model_business_plan.dart';

class ModelBusinessPlanWindow {
  const ModelBusinessPlanWindow({
    required this.plans,
    required this.nextBefore,
    required this.hasMore,
  });

  final List<ModelBusinessPlan> plans;
  final DateTime nextBefore;
  final bool hasMore;
}

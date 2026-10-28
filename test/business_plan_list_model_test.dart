import 'dart:collection';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/model_business_plan_list.dart';

ModelBusinessPlan _plan(String id, String status, int day) => ModelBusinessPlan(
  id: id,
  title: id,
  status: status,
  createdAt: DateTime(2026, 10, day),
  sections: [],
);

class _CountedPlan extends ModelBusinessPlan {
  _CountedPlan(int id)
    : super(
        id: '$id',
        title: '$id',
        status: 'in_progress',
        createdAt: DateTime(2026, 1, 1).add(Duration(minutes: id)),
        sections: [],
      );
  int statusReads = 0, dateReads = 0;
  @override
  String get status {
    statusReads++;
    return super.status;
  }

  @override
  DateTime get createdAt {
    dateReads++;
    return super.createdAt;
  }
}

class _SinglePass extends IterableBase<ModelBusinessPlan> {
  _SinglePass(this.source);
  final List<ModelBusinessPlan> source;
  int reads = 0;
  @override
  Iterator<ModelBusinessPlan> get iterator {
    if (++reads > 1) throw StateError('source traversed twice');
    return source.iterator;
  }
}

List<ModelBusinessPlan> _legacy(Iterable<ModelBusinessPlan> source) {
  final unique = {for (final plan in source) plan.id: plan};
  int rank(String status) => switch (status) {
    'in_progress' => 0,
    'not_started' => 1,
    _ => 2,
  };
  return unique.values.toList()..sort((a, b) {
    final order = rank(a.status).compareTo(rank(b.status));
    return order == 0 ? b.createdAt.compareTo(a.createdAt) : order;
  });
}

void main() {
  test(
    'status priority precedes newest creation date and source is unchanged',
    () {
      final source = [
        _plan('completed', 'completed', 28),
        _plan('older', 'in_progress', 1),
        _plan('newer', 'in_progress', 20),
        _plan('pending', 'not_started', 25),
      ];
      final before = List.of(source);
      expect(ModelBusinessPlanList.ordered(source).map((p) => p.id), [
        'newer',
        'older',
        'pending',
        'completed',
      ]);
      expect(source, before);
    },
  );

  test('duplicate ID uses the final record without merging or mutating it', () {
    final original = _plan('same', 'completed', 1);
    final replacement = _plan('same', 'in_progress', 20);
    final source = _SinglePass([
      original,
      _plan('other', 'not_started', 28),
      replacement,
    ]);
    final result = ModelBusinessPlanList.ordered(source);
    expect(result, [replacement, isA<ModelBusinessPlan>()]);
    expect(result.first, same(replacement));
    expect(result, hasLength(2));
    expect(original.status, 'completed');
    expect(source.reads, 1);
  });

  test('sort keys are read once per unique plan for a large input', () {
    final plans = List.generate(10000, _CountedPlan.new);
    final result = ModelBusinessPlanList.ordered(plans);
    expect(plans.every((p) => p.statusReads == 1 && p.dateReads == 1), isTrue);
    expect(result.first.id, '9999');
    expect(result.last.id, '0');
  });

  test(
    'randomized ties and unknown statuses match the previous implementation',
    () {
      final random = Random(20261028);
      const statuses = [
        'in_progress',
        'not_started',
        'completed',
        'unknown',
        '',
      ];
      for (var batch = 0; batch < 100; batch++) {
        final plans = List.generate(
          200,
          (_) => _plan(
            '${random.nextInt(80)}',
            statuses[random.nextInt(statuses.length)],
            1 + random.nextInt(5),
          ),
        );
        expect(
          ModelBusinessPlanList.ordered(plans),
          _legacy(plans),
          reason: 'batch $batch',
        );
      }
    },
  );

  test('empty input and later replacements do not reuse old result data', () {
    expect(ModelBusinessPlanList.ordered([]), isEmpty);
    final plan = _plan('id', 'completed', 1);
    expect(ModelBusinessPlanList.ordered([plan]), [plan]);
    final changed = plan.copyWith(status: 'in_progress', title: 'Updated');
    final next = ModelBusinessPlanList.ordered([changed]);
    expect(next.single.title, 'Updated');
    expect(next.single.status, 'in_progress');
    expect(plan.title, 'id');
  });
}

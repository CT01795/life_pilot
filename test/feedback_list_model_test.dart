import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/feedback/model_feedback.dart';
import 'package:life_pilot/feedback/model_feedback_list.dart';

ModelFeedback _row(int id, String status, int day) => ModelFeedback(
  id: id,
  subject: '$id',
  content: 'Content',
  createdAt: DateTime(2026, 10, day),
  status: status,
);

class _CountedRow extends ModelFeedback {
  _CountedRow(int id)
    : super(
        id: id,
        subject: '$id',
        content: '',
        createdAt: DateTime(2026).add(Duration(minutes: id)),
        status: 'in_progress',
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

List<ModelFeedback> _legacy(Iterable<ModelFeedback> source) {
  final unique = {for (final row in source) row.id: row};
  int rank(String status) => switch (status) {
    'in_progress' => 0,
    'pending' => 1,
    _ => 2,
  };
  return unique.values.toList()..sort((a, b) {
    final status = rank(a.status).compareTo(rank(b.status));
    return status != 0 ? status : b.createdAt.compareTo(a.createdAt);
  });
}

void main() {
  test(
    'already ordered feedback snapshots keys once and remains read-only',
    () {
      final source = List.generate(10000, _CountedRow.new).reversed.toList();
      final result = ModelFeedbackList.ordered(source);
      expect(result, orderedEquals(source));
      expect(
        source.every((p) => p.statusReads == 1 && p.dateReads == 1),
        isTrue,
      );
      expect(result.first, same(source.first));
      expect(() => result.clear(), throwsUnsupportedError);
    },
  );

  test(
    'duplicate replacement can invalidate an otherwise ordered response',
    () {
      final first = _row(1, 'in_progress', 3);
      final replacement = _row(1, 'completed', 3);
      final source = [
        first,
        _row(2, 'in_progress', 2),
        _row(3, 'in_progress', 1),
        replacement,
      ];
      final result = ModelFeedbackList.ordered(source);
      expect(result, _legacy(source));
      expect(result.map((p) => p.id), [2, 3, 1]);
      expect(result.last, same(replacement));
      expect(first.status, 'in_progress');
    },
  );

  test(
    'status precedes newest creation date and source order is unchanged',
    () {
      final source = [
        _row(1, 'completed', 28),
        _row(2, 'in_progress', 1),
        _row(3, 'pending', 25),
        _row(4, 'in_progress', 20),
      ];
      final before = List.of(source);
      expect(ModelFeedbackList.ordered(source).map((row) => row.id), [
        4,
        2,
        3,
        1,
      ]);
      expect(source, before);
    },
  );

  test('final duplicate wins and returned snapshot is read-only', () {
    final old = _row(1, 'completed', 1), latest = _row(1, 'pending', 20);
    final rows = ModelFeedbackList.ordered([old, latest]);
    expect(rows.single, same(latest));
    expect(old.status, 'completed');
    expect(() => rows.clear(), throwsUnsupportedError);
  });

  test(
    'ordering preserves screenshot and decoded-cache identities without decoding',
    () {
      final row = _row(1, 'pending', 1)
        ..screenshot = ['invalid base64 that must not be decoded here'];
      final decoded = [
        Uint8List.fromList([1, 2, 3]),
      ];
      row.screenshotDecodeRawData = decoded;
      final result = ModelFeedbackList.ordered([row]);
      expect(result.single, same(row));
      expect(result.single.screenshot, same(row.screenshot));
      expect(result.single.screenshotDecodeRawData, same(decoded));
    },
  );

  test('mutable status is evaluated afresh rather than cached', () {
    final a = _row(1, 'in_progress', 1), b = _row(2, 'pending', 20);
    expect(ModelFeedbackList.ordered([a, b]), [a, b]);
    a.status = 'completed';
    expect(ModelFeedbackList.ordered([a, b]), [b, a]);
  });

  test('large input reads each sort key once per unique feedback', () {
    final source = List.generate(10000, _CountedRow.new);
    final result = ModelFeedbackList.ordered(source);
    expect(
      source.every((row) => row.statusReads == 1 && row.dateReads == 1),
      isTrue,
    );
    expect(result.first.id, 9999);
    expect(result.last.id, 0);
  });

  test(
    'randomized ties, duplicates and unknown statuses match original policy',
    () {
      final random = Random(20261028);
      const statuses = ['in_progress', 'pending', 'completed', '', 'unknown'];
      for (var batch = 0; batch < 100; batch++) {
        final source = List.generate(
          200,
          (_) => _row(
            random.nextInt(80),
            statuses[random.nextInt(statuses.length)],
            1 + random.nextInt(5),
          ),
        );
        expect(
          ModelFeedbackList.ordered(source),
          _legacy(source),
          reason: 'batch $batch',
        );
      }
      expect(ModelFeedbackList.ordered([]), isEmpty);
    },
  );
}

import 'dart:collection';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard_detail_query.dart';
import 'package:life_pilot/utils/value_parser.dart';

final _today = DateTime(2026, 10, 20);
Map<String, dynamic> _row(
  int id, {
  Object? value = 1,
  DateTime? date,
  String account = 'account',
  String currency = 'TWD',
}) => {
  'id': '$id',
  'account_id': account,
  'currency': currency,
  'value': value,
  'date': (date ?? _today.add(Duration(minutes: id))).toUtc().toIso8601String(),
};

class _CountedRow extends MapBase<String, dynamic> {
  final Map<String, dynamic> data;
  int dateReads = 0;
  int valueReads = 0;
  int contentReads = 0;
  _CountedRow(this.data);
  @override
  dynamic operator [](Object? key) {
    if (key == 'date') dateReads++;
    if (key == 'value') valueReads++;
    if (key == 'description' || key == 'sub_events') contentReads++;
    return data[key];
  }

  @override
  void operator []=(String key, dynamic value) => data[key] = value;
  @override
  Iterable<String> get keys => data.keys;
  @override
  void clear() => data.clear();
  @override
  dynamic remove(Object? key) => data.remove(key);
}

ModelDashboardDetailQuery _query({String? currency, int previewLimit = 5}) =>
    ModelDashboardDetailQuery(
      now: _today.add(const Duration(hours: 14)),
      accountId: 'account',
      currency: currency,
      previewLimit: previewLimit,
    );

void main() {
  test('total includes all matching records, not only the latest five', () {
    final rows = List.generate(10, (i) => _row(i, value: i + 1));
    final result = _query(currency: 'TWD').selectAccounting(rows);
    expect(result.todayTotal, 55);
    expect(result.previewRows.map((row) => row['id']), [
      '9',
      '8',
      '7',
      '6',
      '5',
    ]);
    expect(result.previewRows.first, same(rows.last));
  });

  test('account, currency and local-day bounds remain independent', () {
    final result = _query(currency: 'TWD').selectAccounting([
      _row(0, value: 10, date: _today),
      _row(
        1,
        value: -2,
        date: _today.add(const Duration(hours: 23, minutes: 59)),
      ),
      _row(2, value: 100, date: _today.subtract(const Duration(seconds: 1))),
      _row(3, value: 100, date: _today.add(const Duration(days: 1))),
      _row(4, value: 100, account: 'other'),
      _row(5, value: 100, currency: 'USD'),
    ]);
    expect(result.todayTotal, 8);
    expect(result.previewRows.map((row) => row['id']), ['1', '0']);
  });

  test('accounting retains signed four-decimal numeric and text amounts', () {
    final result = _query().selectAccounting([
      _row(1, value: '1234.5678'),
      _row(2, value: -0.0001),
      _row(3, value: 'bad'),
      _row(4, value: null),
    ]);
    expect(result.todayTotal, closeTo(1234.5677, 0.00000001));
    expect(result.previewRows.length, 4);
  });

  test('points keep existing per-row integer parsing and signed totals', () {
    final rows = [
      _row(0, value: 1.9),
      _row(1, value: -2.9),
      _row(2, value: '3'),
      _row(3, value: '3.5'),
      _row(4, value: null),
      _row(5, value: 'bad'),
    ];
    final result = _query().selectPoints(rows);
    expect(
      result.todayTotal,
      rows.fold<int>(0, (sum, row) => sum + parseIntValue(row['value'])),
    );
    expect(result.todayTotal, 2);
  });

  test('invalid or missing date does not fall back to created_at', () {
    final rows = [
      _row(1)..['date'] = 'bad',
      _row(2)
        ..remove('date')
        ..['created_at'] = _today.toIso8601String(),
    ];
    final result = _query().selectAccounting(rows);
    expect(result.todayTotal, 0);
    expect(result.previewRows, isEmpty);
  });

  test('equal date keys retain incoming order', () {
    final rows = List.generate(8, (i) => _row(i, date: _today));
    expect(_query().selectAccounting(rows).previewRows, rows.take(5));
  });

  test(
    'read-only sources are not sorted or mutated and preview is read-only',
    () {
      final rows = List<Map<String, dynamic>>.unmodifiable([
        for (var i = 0; i < 20; i++) Map<String, dynamic>.unmodifiable(_row(i)),
      ]);
      final result = _query().selectAccounting(rows);
      expect(rows.first['id'], '0');
      expect(rows.last['id'], '19');
      expect(result.previewRows.first, same(rows.last));
      expect(() => result.previewRows.clear(), throwsUnsupportedError);
    },
  );

  test('one scan reads eligible date/value once without decoding content', () {
    final other = _CountedRow(_row(0, account: 'other'));
    final old = _CountedRow(_row(1, date: DateTime(2020)));
    final current = List.generate(1000, (i) => _CountedRow(_row(i)));
    final result = _query().selectAccounting([other, old, ...current]);
    expect(result.previewRows.length, 5);
    expect(result.todayTotal, 1000);
    expect([other.dateReads, other.valueReads, old.valueReads], [0, 0, 0]);
    expect(
      current.every(
        (row) =>
            row.dateReads == 1 && row.valueReads == 1 && row.contentReads == 0,
      ),
      true,
    );
  });

  test(
    'zero-length preview still calculates total; negative limit is rejected',
    () {
      final result = _query(
        previewLimit: 0,
      ).selectAccounting([_row(0, value: 12)]);
      expect(result.previewRows, isEmpty);
      expect(result.todayTotal, 12);
      expect(() => _query(previewLimit: -1), throwsArgumentError);
    },
  );

  test('generated batches match previous filter, full sort and total', () {
    final random = Random(20261020);
    for (var batch = 0; batch < 100; batch++) {
      final rows = List.generate(
        200,
        (i) => _row(
          i,
          account: random.nextBool() ? 'account' : 'other',
          currency: random.nextBool() ? 'TWD' : 'USD',
          date: _today.add(Duration(seconds: i * 1000 - 10000)),
          value: random.nextInt(200) - 100,
        ),
      )..shuffle(random);
      final expected =
          rows.where((row) {
            final date = tryParseDateTimeValue(row['date'], toLocal: true)!;
            return row['account_id'] == 'account' &&
                row['currency'] == 'TWD' &&
                !date.isBefore(_today) &&
                date.isBefore(_today.add(const Duration(days: 1)));
          }).toList()..sort(
            (a, b) => (b['date'] as String).compareTo(a['date'] as String),
          );
      final result = _query(currency: 'TWD').selectAccounting(rows);
      expect(result.previewRows, expected.take(5));
      expect(
        result.todayTotal,
        expected.fold<num>(0, (sum, row) => sum + parseNumValue(row['value'])),
      );
    }
  });
}

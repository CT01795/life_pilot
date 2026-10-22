import 'dart:collection';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/model_local_account_list.dart';
import 'package:life_pilot/utils/record_row_utils.dart';

class _Rows extends ListBase<RecordRow> {
  _Rows(List<RecordRow> values)
    : _values = List.unmodifiable(
        values.map(Map<String, dynamic>.unmodifiable),
      );
  final List<RecordRow> _values;
  int reads = 0;
  @override
  int get length => _values.length;
  @override
  set length(int value) => throw UnsupportedError('Snapshot');
  @override
  RecordRow operator [](int index) {
    reads++;
    return _values[index];
  }

  @override
  void operator []=(int index, RecordRow value) =>
      throw UnsupportedError('Snapshot');
}

RecordRow _account({
  String id = 'a',
  String currency = 'TWD',
  bool valid = true,
}) => {'id': id, 'main_currency': currency, 'is_valid': valid};
RecordRow _detail(String id, Object value, {String currency = 'TWD'}) => {
  'account_id': id,
  'currency': currency,
  'value': value,
};

void main() {
  num total(_Rows details, {bool points = false, RecordRow? account}) =>
      ModelLocalAccountList.totalForSnapshot(
        details: details,
        account: account ?? _account(),
        points: points,
      );

  for (final points in [false, true]) {
    ModelLocalAccountList page(_Rows rows, List<RecordRow> accounts) =>
        ModelLocalAccountList.fromSnapshots(
          accounts: accounts,
          details: rows,
          points: points,
        );
    test(
      '$points: list totals are reused by exact and repeated list reads',
      () {
        final rows = _Rows([_detail('a', 10), _detail('b', 20)]);
        final accounts = [_account(), _account(id: 'b')];
        expect(page(rows, accounts).totalFor(accounts.first), 10);
        final reads = rows.reads;
        expect(total(rows, points: points), 10);
        expect(page(rows, accounts).totalFor(accounts.last), 20);
        expect(rows.reads, reads);
      },
    );
    test('$points: exact totals are reused by a later list read', () {
      final rows = _Rows([_detail('a', 10)]);
      expect(total(rows, points: points), 10);
      final reads = rows.reads;
      expect(page(rows, [_account()]).totalFor(_account()), 10);
      expect(rows.reads, reads);
    });
    test('$points: expanding selection computes missing totals only once', () {
      final rows = _Rows([_detail('a', 10), _detail('b', 20)]);
      page(rows, [_account()]);
      final reads = rows.reads;
      final accounts = [_account(), _account(id: 'b')];
      final expanded = page(rows, accounts);
      expect(expanded.totalFor(accounts.first), 10);
      expect(expanded.totalFor(accounts.last), 20);
      expect(rows.reads, greaterThan(reads));
      final expandedReads = rows.reads;
      page(rows, accounts);
      expect(rows.reads, expandedReads);
    });
    test('$points: list selection still honors changed account validity', () {
      final rows = _Rows([_detail('a', 10)]);
      page(rows, [_account()]);
      expect(page(rows, [_account(valid: false)]).rows, isEmpty);
      final fresh = _Rows([_detail('a', 40)]);
      expect(page(fresh, [_account()]).totalFor(_account()), 40);
    });
    test('$points: repeats reuse a total without revisiting detail rows', () {
      final rows = _Rows([
        _detail('a', 10),
        _detail('a', -2),
        _detail('other', 999),
      ]);
      expect(total(rows, points: points), 8);
      final reads = rows.reads;
      expect(reads, greaterThan(0));
      for (var i = 0; i < 20; i++) {
        expect(total(rows, points: points), 8);
      }
      expect(rows.reads, reads);
    });
    test('$points: zero is a cached result, not a missing total', () {
      final rows = _Rows([_detail('a', 10), _detail('a', -10)]);
      expect(total(rows, points: points), 0);
      final reads = rows.reads;
      expect(total(rows, points: points), 0);
      expect(rows.reads, reads);
    });
    test(
      '$points: new owner/resource snapshots with identical IDs stay separate',
      () {
        final first = _Rows([_detail('a', 10)]);
        final second = _Rows([_detail('a', 200)]);
        expect(total(first, points: points), 10);
        expect(total(second, points: points), 200);
        expect(total(first, points: points), 10);
      },
    );
    test('$points: edited and deleted details require a fresh snapshot', () {
      final before = _Rows([_detail('a', 10)]);
      final edited = _Rows([_detail('a', 20)]);
      final deleted = _Rows([]);
      expect(total(before, points: points), 10);
      expect(total(edited, points: points), 20);
      expect(total(deleted, points: points), 0);
    });
  }

  test(
    'account ID and accounting currency both participate in the cache key',
    () {
      final rows = _Rows([
        _detail('a', 10),
        _detail('a', 50, currency: 'USD'),
        _detail('b', 90),
      ]);
      expect(total(rows), 10);
      expect(total(rows, account: _account(currency: 'USD')), 50);
      expect(total(rows, account: _account(id: 'b')), 90);
      expect(total(rows), 10);
    },
  );
  test(
    'integer point rules cannot reuse accounting decimal/currency totals',
    () {
      final rows = _Rows([
        _detail('a', '12.3456'),
        _detail('a', -2),
        _detail('a', 100, currency: 'USD'),
      ]);
      for (final points in [false, true]) {
        final account = _account();
        final reference = points
            ? ModelLocalAccountList.points([account], rows)
            : ModelLocalAccountList.accounting([account], rows);
        expect(total(rows, points: points), reference.totalFor(account));
      }
    },
  );
  test('invalid accounts do not poison a later valid account total', () {
    final rows = _Rows([_detail('a', 10)]);
    expect(total(rows, account: _account(valid: false)), 0);
    expect(rows.reads, 0);
    expect(total(rows), 10);
  });
  test('total calculation reads no photos or unrelated display metadata', () {
    final rows = _Rows([
      {
        ..._detail('a', 10),
        'date': '2000-01-01',
        'primary_category': 'reserved',
        'type': 'other',
        'master_graph_url': Object(),
        'sub_events': Object(),
      },
    ]);
    expect(total(rows), 10);
  });
}

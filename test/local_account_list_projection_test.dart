import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/model_local_account_list.dart';
import 'package:life_pilot/utils/record_row_utils.dart';
import 'package:life_pilot/utils/value_parser.dart';

RecordRow _account(
  String id, {
  String category = 'personal',
  String currency = 'TWD',
  String created = '',
  bool valid = true,
}) => {
  'id': id,
  'category': category,
  'main_currency': currency,
  'created_at': created,
  'is_valid': valid,
};
RecordRow _detail(String account, Object? value, {String currency = 'TWD'}) => {
  'account_id': account,
  'value': value,
  'currency': currency,
};
List<RecordRow> _legacyRows(
  List<RecordRow> source,
  String? category,
  int? limit,
) {
  var rows = source
      .where(
        (r) =>
            r['is_valid'] == true &&
            (category == null || parseStringValue(r['category']) == category),
      )
      .toList();
  if (category == null && limit != null) {
    final personal = rows.where((r) => r['category'] == 'personal');
    final projects = rows.where((r) => r['category'] == 'project').toList()
      ..sort(
        (a, b) => parseStringValue(
          b['created_at'],
        ).compareTo(parseStringValue(a['created_at'])),
      );
    rows = [...personal, ...projects.take(limit)];
  }
  return rows;
}

void main() {
  ModelLocalAccountList build(
    Iterable<RecordRow> accounts,
    Iterable<RecordRow> details, {
    bool points = false,
    String? category,
    int? limit,
  }) =>
      (points
      ? ModelLocalAccountList.points
      : ModelLocalAccountList.accounting)(
        accounts,
        details,
        category: category,
        projectLimit: limit,
      );
  for (final points in [false, true]) {
    group(points ? 'points' : 'accounting', () {
      test(
        'matches legacy account selection and totals in 100 random batches',
        () {
          final random = Random(77);
          for (var batch = 0; batch < 100; batch++) {
            final accounts = List.generate(
              30,
              (i) => _account(
                '$i',
                category: ['personal', 'project', 'unknown'][random.nextInt(3)],
                currency: random.nextBool() ? 'TWD' : 'USD',
                created: '2026-10-${random.nextInt(20) + 1}',
                valid: random.nextInt(5) != 0,
              ),
            );
            final details = List.generate(
              150,
              (i) => _detail(
                '${random.nextInt(35)}',
                i % 5 == 0 ? '-12.3456' : random.nextInt(50) - 20.1234,
                currency: random.nextBool() ? 'TWD' : 'USD',
              ),
            );
            final category = [
              null,
              'personal',
              'project',
              'unknown',
            ][batch % 4];
            final limit = [null, 0, 2][batch % 3];
            final expected = _legacyRows(accounts, category, limit);
            final page = build(
              accounts,
              details,
              points: points,
              category: category,
              limit: limit,
            );
            expect(page.rows, expected);
            for (final account in expected) {
              final total = details
                  .where(
                    (d) =>
                        parseStringValue(d['account_id']) ==
                            parseStringValue(account['id']) &&
                        (points ||
                            parseStringValue(d['currency']) ==
                                parseStringValue(account['main_currency'])),
                  )
                  .fold<num>(
                    0,
                    (sum, d) =>
                        sum +
                        (points
                            ? parseIntValue(d['value'])
                            : parseNumValue(d['value'])),
                  );
              expect(
                page.totalFor(account),
                total,
                reason: '$batch/${account['id']}',
              );
            }
          }
        },
      );
      test('details are visited once for all 1000 displayed accounts', () {
        var visits = 0;
        Iterable<RecordRow> details() sync* {
          for (var i = 0; i < 10000; i++) {
            visits++;
            yield _detail('${i % 1000}', 1);
          }
        }

        final accounts = List.generate(1000, (i) => _account('$i'));
        final page = build(accounts, details(), points: points);
        expect(visits, 10000);
        expect(page.rows.every((a) => page.totalFor(a) == 10), true);
      });
      test('no displayed accounts avoids scanning detail input', () {
        Iterable<RecordRow> details() sync* {
          throw StateError('unnecessary detail scan');
        }

        final page = build(
          [_account('a', valid: false)],
          details(),
          points: points,
        );
        expect(page.rows, isEmpty);
      });
      test('all dates/types/reserved rows remain part of account totals', () {
        final account = _account('a');
        final page = build(
          [account],
          [
            {
              ..._detail('a', 10),
              'date': '2020-01-01',
              'primary_category': 'reserved',
              'type': 'other',
            },
            {..._detail('a', -3), 'date': '2030-01-01'},
            _detail('orphan', 999),
          ],
          points: points,
        );
        expect(page.totalFor(account), 7);
      });
    });
  }
  test(
    'personal order and latest two projects retain current selection rules',
    () {
      final accounts = [
        _account('p2'),
        _account('old', category: 'project', created: '2020'),
        _account('p1'),
        _account('new', category: 'project', created: '2026'),
        _account('middle', category: 'project', created: '2025'),
        _account('other', category: 'unknown'),
      ];
      expect(build(accounts, [], limit: 2).rows.map((r) => r['id']), [
        'p2',
        'p1',
        'new',
        'middle',
      ]);
      expect(build(accounts, [], category: 'project', limit: 0).rows.length, 3);
    },
  );
  test('accounting splits exact currency codes; points ignore currency', () {
    final a = _account('a'), b = _account('b', currency: 'USD');
    final details = [
      _detail('a', 10),
      _detail('a', 99, currency: 'USD'),
      _detail('a', 999, currency: 'twd'),
      _detail('b', 5, currency: 'USD'),
    ];
    expect(build([a, b], details).totalFor(a), 10);
    expect(build([a, b], details).totalFor(b), 5);
    expect(build([a, b], details, points: true).totalFor(a), 1108);
  });
  test(
    'fractional accounting and per-row integer point parsing remain distinct',
    () {
      final account = _account('a');
      final details = [
        _detail('a', -12.3456),
        _detail('a', '0.0001'),
        _detail('a', 1.9),
      ];
      expect(
        build([account], details).totalFor(account),
        closeTo(-10.4455, 0.00000001),
      );
      expect(build([account], details, points: true).totalFor(account), -11);
    },
  );
  test('duplicate account keys do not double-count amounts', () {
    final a = _account('a');
    final page = build([a, _account('a')], [_detail('a', 10)]);
    expect(page.rows.length, 2);
    expect(page.rows.every((a) => page.totalFor(a) == 10), true);
  });
  test(
    'read-only source identity/order remain unchanged and edits require rebuild',
    () {
      final a = Map<String, dynamic>.unmodifiable(_account('a'));
      final source = List<RecordRow>.unmodifiable([a]);
      final page = build(source, [_detail('a', 10)]);
      expect(page.rows.single, same(a));
      expect(() => page.rows.clear(), throwsUnsupportedError);
      expect(build(source, [_detail('a', 20)]).totalFor(a), 20);
      expect(page.totalFor(a), 10);
    },
  );
  test(
    'negative project limit retains rejection rather than removing the limit',
    () {
      expect(() => build([_account('a')], [], limit: -1), throwsArgumentError);
    },
  );
}

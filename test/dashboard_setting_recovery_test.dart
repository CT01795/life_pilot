import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_setting.dart';

Map<String, dynamic> _row(String id, {Object? valid = true, String? name}) => {
  'id': id,
  'account': name ?? id,
  'is_valid': valid,
};

void main() {
  DashboardSetting recover({
    Iterable<Map<String, dynamic>> accounting = const [],
    Iterable<Map<String, dynamic>> points = const [],
  }) => DashboardSetting.fromLocalAccounts(
    accountingAccounts: accounting,
    pointAccounts: points,
  );

  test('empty account resources preserve original default settings', () {
    final setting = recover();
    expect(setting.recommendEventCity, '台北');
    expect(setting.recommendPlaceCity, '台北');
    expect(setting.language, 'zh');
    expect(setting.accountingAccountId, isNull);
    expect(setting.pointAccountId, isNull);
  });

  test('selects first valid account without sorting either source', () {
    final setting = recover(
      accounting: [_row('invalid', valid: false), _row('z'), _row('a')],
      points: [_row('p2'), _row('p1')],
    );
    expect(setting.accountingAccountId, 'z');
    expect(setting.accountingAccountName, 'z');
    expect(setting.pointAccountId, 'p2');
    expect(setting.pointAccountName, 'p2');
  });

  test('only boolean true marks an account as valid', () {
    final setting = recover(
      accounting: [
        _row('null', valid: null),
        _row('string', valid: 'true'),
        _row('number', valid: 1),
        _row('valid'),
      ],
    );
    expect(setting.accountingAccountId, 'valid');
  });

  test('account resources remain independent even with identical IDs', () {
    final setting = recover(
      accounting: [_row('same', name: 'Cash')],
      points: [_row('same', name: 'Learning')],
    );
    expect(setting.accountingAccountName, 'Cash');
    expect(setting.pointAccountName, 'Learning');
  });

  test('does not replace missing fields with another valid account', () {
    final setting = recover(
      accounting: [
        {'is_valid': true},
        _row('later'),
      ],
    );
    expect(setting.accountingAccountId, isNull);
    expect(setting.accountingAccountName, isNull);
  });

  test('all invalid accounts leave both selections empty', () {
    final setting = recover(
      accounting: [_row('a', valid: false)],
      points: [_row('p', valid: null)],
    );
    expect(setting.accountingAccountId, isNull);
    expect(setting.pointAccountId, isNull);
  });

  test('accepts read-only sources and serializes recovered fields', () {
    final row = Map<String, dynamic>.unmodifiable(_row('a', name: 'Cash'));
    final rows = List<Map<String, dynamic>>.unmodifiable([row]);
    final setting = recover(accounting: rows);
    final restored = DashboardSetting.fromJson(setting.toJson());
    expect(restored.accountingAccountId, 'a');
    expect(restored.accountingAccountName, 'Cash');
    expect(rows.single, row);
  });

  test('stops scanning each source after the first valid row', () {
    Iterable<Map<String, dynamic>> source(String id) sync* {
      yield _row(id);
      throw StateError('unexpected further scan');
    }

    final setting = recover(accounting: source('a'), points: source('p'));
    expect(setting.accountingAccountId, 'a');
    expect(setting.pointAccountId, 'p');
  });
}

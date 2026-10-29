import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/accounting/controller_accounting_list.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/point_record/controller_point_record_list.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

void main() {
  for (final accounting in [true, false]) {
    late SafeChangeNotifier controller;
    late void Function(int) adjust;
    late Object Function() row;
    late num Function() total;
    late int notifications;
    group(accounting ? 'accounting' : 'points', () {
      setUp(() {
        if (accounting) {
          final c =
              ControllerAccountingList(service: ServiceAccounting(), auth: null)
                ..accounts = [
                  ModelAccountingAccount(
                    id: 'a',
                    accountName: 'A',
                    category: 'personal',
                    balance: 10.125,
                    currency: 'TWD',
                  ),
                ];
          controller = c;
          adjust = (delta) => c.updateAccountTotals(
            accountId: 'a',
            deltaBalance: delta,
            currency: 'TWD',
          );
          row = () => c.accounts.single;
          total = () => c.accounts.single.balance;
        } else {
          final c =
              ControllerPointRecordList(
                  service: ServicePointRecord(),
                  auth: null,
                )
                ..accounts = [
                  ModelPointRecordAccount(
                    id: 'a',
                    accountName: 'A',
                    category: 'personal',
                    points: 10,
                  ),
                ];
          controller = c;
          adjust = (delta) =>
              c.updateAccountTotals(accountId: 'a', deltaPoints: delta);
          row = () => c.accounts.single;
          total = () => c.accounts.single.points;
        }
        notifications = 0;
        controller.addListener(() => notifications++);
      });
      tearDown(() {
        if (!controller.notifierDisposed) controller.dispose();
      });
      test('zero delta keeps row identity without notifying', () {
        final snapshot = row();
        adjust(0);
        expect(row(), same(snapshot));
        expect(notifications, 0);
      });
      test('positive and negative adjustments still update totals', () {
        final initial = total();
        adjust(5);
        expect(total(), initial + 5);
        adjust(-3);
        expect(total(), initial + 2);
        expect(notifications, 2);
      });
      test('late adjustment after disposal cannot mutate rows', () {
        final snapshot = row();
        controller.dispose();
        adjust(5);
        expect(row(), same(snapshot));
      });
    });
  }
}

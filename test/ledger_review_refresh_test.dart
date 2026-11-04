import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/accounting/controller_ledger_review_refresh.dart';

void main() {
  test('multiple approvals refresh the account once on return', () {
    var reads = 0;
    final refresh = ControllerLedgerReviewRefresh(() => reads++);
    refresh.approved();
    refresh.approved();
    expect(reads, 0);
    refresh.close();
    refresh.close();
    expect(reads, 1);
  });

  test('no approvals skips refresh, but a late approval refreshes', () {
    var reads = 0;
    final refresh = ControllerLedgerReviewRefresh(() => reads++);
    refresh.close();
    expect(reads, 0);
    refresh.approved();
    expect(reads, 1);
  });
}

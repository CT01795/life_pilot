import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/accounting/controller_shared_ledger_overview.dart';
import 'package:life_pilot/accounting/service_ledger_sharing.dart';

class _FakeSharing extends ServiceLedgerSharing {
  _FakeSharing({this.marker = false});
  final bool marker;
  final requests = <(int, int)>[];
  final rows = List.generate(15, (i) => <String, dynamic>{'share_id': '$i'});

  @override
  Future<List<Map<String, dynamic>>> overviewPage(
    LedgerKind kind,
    int offset, {
    required int limit,
    required int visibleLimit,
  }) async {
    requests.add((offset, limit));
    return [
      for (final (index, row) in rows.skip(offset).take(limit).indexed)
        if (marker && index >= visibleLimit) {'share_id': null} else row,
    ];
  }
}

void main() {
  test('look-ahead marker is replaced by the next real account', () async {
    final service = _FakeSharing(marker: true);
    final controller = ControllerSharedLedgerOverview(
      LedgerKind.accounting,
      service: service,
    );
    final initial = await controller.refresh(6);
    expect(initial.last['share_id'], isNull);
    final second = await controller.next(initial);
    expect(second.take(12), service.rows.take(12));
    expect(second.last['share_id'], isNull);
    final last = await controller.next(second);
    expect(last, service.rows);
    expect(service.requests, [(0, 7), (6, 7), (12, 7)]);
  });
  test('next page does not request already loaded shares', () async {
    final service = _FakeSharing();
    final controller = ControllerSharedLedgerOverview(
      LedgerKind.accounting,
      service: service,
    );
    final initial = await controller.refresh(6);
    final second = await controller.next(initial);
    final last = await controller.next(second);
    expect(service.requests, [(0, 7), (7, 6), (13, 6)]);
    expect(second, service.rows.take(13));
    expect(last, service.rows);
  });
}

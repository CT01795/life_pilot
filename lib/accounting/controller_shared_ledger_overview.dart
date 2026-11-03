import 'package:life_pilot/accounting/service_ledger_sharing.dart';

/// Keeps a look-ahead marker without requiring its statistics.
class ControllerSharedLedgerOverview {
  ControllerSharedLedgerOverview(this.kind, {ServiceLedgerSharing? service})
    : _service = service ?? ServiceLedgerSharing();

  static const pageSize = 6;
  final LedgerKind kind;
  final ServiceLedgerSharing _service;

  Future<List<Map<String, dynamic>>> refresh(int visibleLimit) async {
    final rows = <Map<String, dynamic>>[];
    while (rows.length <= visibleLimit) {
      final limit = (visibleLimit + 1 - rows.length).clamp(1, 100);
      final page = await _service.overviewPage(
        kind,
        rows.length,
        limit: limit,
        visibleLimit: (visibleLimit - rows.length).clamp(0, limit),
      );
      rows.addAll(page);
      if (page.length < limit) break;
    }
    return List.unmodifiable(rows);
  }

  Future<List<Map<String, dynamic>>> next(
    List<Map<String, dynamic>> current,
  ) async {
    final hasMarker = current.isNotEmpty && current.last['share_id'] == null;
    final loaded = hasMarker ? current.take(current.length - 1) : current;
    final limit = hasMarker ? pageSize + 1 : pageSize;
    final nextRows = await _service.overviewPage(
      kind,
      loaded.length,
      limit: limit,
      visibleLimit: limit - 1,
    );
    final byId = {
      for (final row in [...loaded, ...nextRows]) row['share_id']: row,
    };
    return List.unmodifiable(byId.values);
  }

  Future<void> decline(String shareId) => _service.decline(shareId);
}

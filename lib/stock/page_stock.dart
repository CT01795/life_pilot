import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/stock/controller_stock.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/service_stock.dart';
import 'package:life_pilot/stock/widgets_stock_date_selector.dart';
import 'package:life_pilot/stock/widgets_stock_search.dart';
import 'package:life_pilot/stock/widgets_stock_card.dart';
import 'package:life_pilot/stock/widgets_stock_foreign_ranking.dart';
import 'package:life_pilot/stock/widgets_stock_futures.dart';
import 'package:life_pilot/stock/widgets_stock_section_failure.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:provider/provider.dart';

class PageStock extends StatelessWidget {
  const PageStock({super.key, this.service});
  final ServiceStock? service;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ControllerStock(service ?? ServiceStock())..load(),
      child:
          Selector<
            ControllerStock,
            ({bool loading, bool failed, List<ModelStock> stocks})
          >(
            selector: (_, c) => (
              loading: c.loading,
              failed: c.loadFailed,
              stocks: c.visibleStocks,
            ),
            shouldRebuild: (previous, next) => previous != next,
            child: const _StockDashboard(),
            builder: (context, state, dashboard) {
              final controller = context.read<ControllerStock>();
              if (state.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.failed && controller.stocks.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    if (controller.latestAvailableDate != null) ...[
                      _buildDateSelector(context, controller),
                      Gaps.h8,
                    ],
                    _buildLoadFailure(context, controller),
                  ],
                );
              }

              final visibleStocks = state.stocks;
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: visibleStocks.length + 1,
                itemBuilder: (context, index) {
                  if (index > 0) {
                    final stockIndex = index - 1;
                    return WidgetsStockCard(
                      stock: visibleStocks[stockIndex],
                      index: stockIndex,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDateSelector(context, controller),
                      Gaps.h8,
                      Selector<ControllerStock, String>(
                        selector: (_, c) => c.searchQuery,
                        builder: (_, query, _) => WidgetsStockSearch(
                          query: query,
                          onChanged: controller.setSearchQuery,
                        ),
                      ),
                      Gaps.h8,
                      Selector<ControllerStock, StockUpdateStatus>(
                        selector: (_, c) => c.updateStatus,
                        builder: (context, status, _) =>
                            status == StockUpdateStatus.idle
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildUpdateStatus(context, status),
                              ),
                      ),

                      /// =========================
                      /// 📊 DASHBOARD（放最上面）
                      /// =========================
                      if (controller.stocks.isEmpty)
                        _buildEmptyState(context)
                      else ...[
                        dashboard!,
                        Gaps.h8,
                      ],

                      /// =========================
                      /// 📈 STOCK LIST
                      /// =========================
                    ],
                  );
                },
              );
            },
          ),
    );
  }
}

Widget _buildDateSelector(BuildContext context, ControllerStock controller) {
  return Selector<ControllerStock, (DateTime?, DateTime?, bool, bool)>(
    selector: (_, c) =>
        (c.selectedDate, c.latestAvailableDate, c.dateLoading, c.canSelectDate),
    builder: (context, state, _) => WidgetsStockDateSelector(
      selectedDate: state.$1,
      latestAvailableDate: state.$2,
      loading: state.$3,
      enabled: state.$4,
      onSelected: controller.loadDate,
    ),
  );
}

Widget _buildLoadFailure(BuildContext context, ControllerStock controller) {
  final loc = AppLocalizations.of(context)!;

  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.red),
          Gaps.h8,
          Text(
            loc.stockLoadFailed,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          Gaps.h16,
          FilledButton.icon(
            onPressed: controller.load,
            icon: const Icon(Icons.refresh),
            label: Text(loc.stockRetry),
          ),
        ],
      ),
    ),
  );
}

Widget _buildEmptyState(BuildContext context) {
  final loc = AppLocalizations.of(context)!;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        const Icon(Icons.query_stats, size: 48, color: Colors.grey),
        Gaps.h8,
        Text(
          loc.stockNoData,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    ),
  );
}

Widget _buildUpdateStatus(BuildContext context, StockUpdateStatus status) {
  final loc = AppLocalizations.of(context)!;
  final (icon, color, message) = switch (status) {
    StockUpdateStatus.updating => (
      Icons.sync,
      Colors.blue,
      loc.stockUpdateInProgress,
    ),
    StockUpdateStatus.succeeded => (
      Icons.check_circle_outline,
      Colors.green,
      loc.stockUpdateSucceeded,
    ),
    StockUpdateStatus.failed => (
      Icons.error_outline,
      Colors.red,
      loc.stockUpdateFailed,
    ),
    StockUpdateStatus.idle => (Icons.info_outline, Colors.grey, ''),
  };

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      border: Border.all(color: color.withValues(alpha: 0.4)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        if (status == StockUpdateStatus.updating)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          )
        else
          Icon(icon, color: color),
        Gaps.w8,
        Expanded(child: Text(message)),
      ],
    ),
  );
}

/// Keep the dashboard subtree stable when the stock list is filtered. Its
/// section selectors still observe fresh data, loading, errors and locale.
class _StockDashboard extends StatelessWidget {
  const _StockDashboard();

  @override
  Widget build(BuildContext context) =>
      _buildDashboard(context, context.read<ControllerStock>());
}

Widget _buildDashboard(BuildContext context, ControllerStock c) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Selector<ControllerStock, (List<ModelFuture>, bool, Object?)>(
      selector: (_, c) => (c.visibleFutures, c.futuresLoading, c.futuresError),
      builder: (context, state, _) => WidgetsStockFutures(
        items: state.$1,
        loading: state.$2,
        error: state.$3,
        onRetry: c.retryFutures,
      ),
    ),
    Gaps.h32,
    Selector<ControllerStock, Object?>(
      selector: (_, c) => c.institutionalsError,
      builder: (_, error, _) => error == null
          ? const SizedBox.shrink()
          : WidgetsStockSectionFailure(
              error: error,
              onRetry: c.retryInstitutionals,
            ),
    ),
    const _StockForeignRankingSelector(isBuy: true),
    Gaps.h8,
    const _StockForeignRankingSelector(isBuy: false),
  ],
);

/// Buy and sell results can change independently while a keyword is edited.
/// Observe each projection separately rather than rebuilding both rankings.
class _StockForeignRankingSelector extends StatelessWidget {
  const _StockForeignRankingSelector({required this.isBuy});
  final bool isBuy;

  @override
  Widget build(BuildContext context) =>
      Selector<
        ControllerStock,
        ({List<ModelInstitutional> items, bool loading, bool failed})
      >(
        selector: (_, c) => (
          items: isBuy ? c.visibleForeignBuy : c.visibleForeignSell,
          loading: c.institutionalsLoading,
          failed: c.institutionalsError != null,
        ),
        // Different keywords may produce new lists containing the same rows.
        // Preserve that section's widgets and expansion when its result is equal.
        shouldRebuild: (previous, next) =>
            previous.loading != next.loading ||
            previous.failed != next.failed ||
            !listEquals(previous.items, next.items),
        builder: (context, state, _) {
          final loc = AppLocalizations.of(context)!;
          return WidgetsStockForeignRanking(
            key: ValueKey(
              isBuy ? 'foreign-buy-ranking' : 'foreign-sell-ranking',
            ),
            title: isBuy ? loc.stockForeignBuy : loc.stockForeignSell,
            items: state.items,
            isBuy: isBuy,
            loading: state.loading,
            failed: state.failed,
          );
        },
      );
}

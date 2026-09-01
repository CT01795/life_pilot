// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/stock/controller_stock.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/service_stock.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class PageStock extends StatelessWidget {
  const PageStock({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ControllerStock(ServiceStock())..load(),
      child: Consumer<ControllerStock>(
        builder: (context, controller, _) {
          if (controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.loadFailed && controller.stocks.isEmpty) {
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

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: controller.stocks.length + 1,
            itemBuilder: (context, index) {
              if (index > 0) {
                final stockIndex = index - 1;
                return _buildStockCard(
                  context,
                  controller.stocks[stockIndex],
                  stockIndex,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDateSelector(context, controller),
                  Gaps.h8,
                  if (controller.updateStatus != StockUpdateStatus.idle) ...[
                    _buildUpdateStatus(context, controller.updateStatus),
                    Gaps.h8,
                  ],

                  /// =========================
                  /// 📊 DASHBOARD（放最上面）
                  /// =========================
                  if (controller.stocks.isEmpty)
                    _buildEmptyState(context)
                  else ...[
                    _buildDashboard(context, controller),
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
  final loc = AppLocalizations.of(context)!;
  final selectedDate = controller.selectedDate ?? DateTime.now();
  final latestAvailableDate = controller.latestAvailableDate ?? DateTime.now();
  return OutlinedButton.icon(
    onPressed: !controller.canSelectDate
        ? null
        : () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(2000),
              lastDate: latestAvailableDate,
            );
            if (picked != null) await controller.loadDate(picked);
          },
    icon: controller.dateLoading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.calendar_month_outlined),
    label: Text(
      '${loc.stockSelectDate}: ${DateFormat('yyyy/MM/dd').format(selectedDate)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

Widget _buildLoadFailure(
  BuildContext context,
  ControllerStock controller,
) {
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
    StockUpdateStatus.idle => (
        Icons.info_outline,
        Colors.grey,
        '',
      ),
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
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: color,
            ),
          )
        else
          Icon(icon, color: color),
        Gaps.w8,
        Expanded(child: Text(message)),
      ],
    ),
  );
}

Widget _buildDashboard(BuildContext context, ControllerStock c) {
  final loc = AppLocalizations.of(context)!;
  final integerFormat = NumberFormat('#,##0');
  final onSurface = Theme.of(context).colorScheme.onSurface;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        loc.stockDashboardTitle,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      Gaps.h8,
      ...c.futures.map(
        //.take(30).map(
        (e) => RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 20,
              color: onSurface,
            ),
            children: [
              TextSpan(
                text: "${e.productName?.trim()} ${e.identityType?.trim()} ",
              ),
              TextSpan(
                text: '${integerFormat.format(e.oiNetQty)} ',
                style: TextStyle(
                  color: (e.oiNetQty ?? 0) >= 0 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: "Net:",
              ),
              TextSpan(
                text: '${integerFormat.format(e.oiNetQtyDiff)} ',
                style: TextStyle(
                  color: (e.oiNetQtyDiff ?? 0) > 0 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
      Gaps.h32,
      _ForeignRankingSection(
        key: const ValueKey('foreign-buy-ranking'),
        title: loc.stockForeignBuy,
        items: c.foreignBuy,
        isBuy: true,
      ),
      Gaps.h8,
      _ForeignRankingSection(
        key: const ValueKey('foreign-sell-ranking'),
        title: loc.stockForeignSell,
        items: c.foreignSell,
        isBuy: false,
      ),
    ],
  );
}

class _ForeignRankingSection extends StatefulWidget {
  const _ForeignRankingSection({
    super.key,
    required this.title,
    required this.items,
    required this.isBuy,
  });

  final String title;
  final List<ModelInstitutional> items;
  final bool isBuy;

  @override
  State<_ForeignRankingSection> createState() => _ForeignRankingSectionState();
}

class _ForeignRankingSectionState extends State<_ForeignRankingSection> {
  static const int _initialCount = 10;
  static const int _pageSize = 20;
  int _visibleCount = _initialCount;

  @override
  void didUpdateWidget(covariant _ForeignRankingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) {
      _visibleCount = _initialCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final integerFormat = NumberFormat('#,##0');
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final itemCount = widget.items.length < _visibleCount
        ? widget.items.length
        : _visibleCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Text(
              '$itemCount / ${widget.items.length}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        Gaps.h8,
        for (final item in widget.items.take(itemCount))
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 20, color: onSurface),
              children: [
                TextSpan(
                  text: '${item.stockNo.trim()} ${item.stockName.trim()} ',
                ),
                TextSpan(
                  text: '${integerFormat.format(item.foreignDiff / 1000)} ',
                  style: TextStyle(
                    color: widget.isBuy ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: 'Net:'),
                TextSpan(
                  text: '${integerFormat.format(item.totalDiff / 1000)} ',
                  style: TextStyle(
                    color: widget.isBuy
                        ? (item.foreignDiff < item.totalDiff
                            ? Colors.red
                            : Colors.blue)
                        : (item.foreignDiff > item.totalDiff
                            ? Colors.green
                            : Colors.blue),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(text: loc.stockThousandLots),
              ],
            ),
          ),
        if (itemCount < widget.items.length)
          TextButton(
            onPressed: () => setState(() => _visibleCount += _pageSize),
            child: Text(loc.clickHereToSeeMore),
          ),
      ],
    );
  }
}

Widget _buildStockCard(BuildContext context, ModelStock stock, int index) {
  final loc = AppLocalizations.of(context)!;
  final colorScheme = Theme.of(context).colorScheme;
  final isUp =
      stock.change?.contains('+') == true || (stock.pctChange ?? 0) > 0;
  return Card(
    elevation: 2,
    margin: const EdgeInsets.symmetric(vertical: 6),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔹 第一行：股號 + 名稱（可點擊）
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final url = Uri.parse(
                  "https://tw.stock.yahoo.com/quote/${stock.securityCode}");
              await launchUrl(url, mode: LaunchMode.externalApplication);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    "${index + 1}. ",
                  ),
                  Gaps.w8,
                  Text(
                    stock.securityCode,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  Gaps.w8,
                  Expanded(
                    child: Text(
                      "${stock.securityName} ${stock.signalText ?? ''} ${stock.predPct?.toStringAsFixed(2) ?? ""}",
                      style: TextStyle(
                        color: stock.signal == 1
                            ? Colors.red
                            : (stock.signal == -1
                                ? Colors.green
                                : colorScheme.onSurface),
                        fontWeight: stock.signal != 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Gaps.h8,

          /// 🔹 第二行：收盤價 + 漲跌
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                loc.stockClosingPrice(
                  NumberFormat('#,##0.00').format(stock.closingPrice),
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (stock.pctChange != null)
                Text(
                  '${stock.pctChange!.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: isUp ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (stock.peRatio != null && stock.peRatio != 0)
                Text("P/E: ${stock.peRatio}"),
            ],
          ),
          Gaps.h8,

          /// 🔹 第三行：其他資訊
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (stock.rsi != null)
                Text(
                  'RSI: ${stock.rsi!.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: stock.rsi! < 50 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Text(
                loc.stockTradingVolume(
                  NumberFormat('#,##0')
                      .format((stock.tradedNumber ?? 0) / 1000),
                ),
              ),
            ],
          ),
          Gaps.h8,

          /// 🔹 第四行：其他資訊
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${DateFormat('M/d').format(stock.date)} ${stock.level ?? ''}",
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

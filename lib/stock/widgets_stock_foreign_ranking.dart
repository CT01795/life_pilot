import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/stock_display_formats.dart';
import 'package:life_pilot/utils/const.dart';

/// View-only incremental rendering; filtering and ranking remain in Model and
/// Controller. Status updates retain expansion; a new result list resets it.
class WidgetsStockForeignRanking extends StatefulWidget {
  const WidgetsStockForeignRanking({
    super.key,
    required this.title,
    required this.items,
    required this.isBuy,
    this.loading = false,
    this.failed = false,
  });

  final String title;
  final List<ModelInstitutional> items;
  final bool isBuy;
  final bool loading;
  final bool failed;

  @override
  State<WidgetsStockForeignRanking> createState() =>
      _WidgetsStockForeignRankingState();
}

class _WidgetsStockForeignRankingState
    extends State<WidgetsStockForeignRanking> {
  static const int _initialCount = 10;
  static const int _pageSize = 20;
  int _visibleCount = _initialCount;

  @override
  void didUpdateWidget(covariant WidgetsStockForeignRanking oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) {
      _visibleCount = _initialCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final formats = StockDisplayFormats.forLocale(loc.localeName);
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (widget.loading)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                '$itemCount / ${widget.items.length}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        Gaps.h8,
        if (!widget.loading && !widget.failed && widget.items.isEmpty)
          Text(loc.noData),
        for (final item in widget.items.take(itemCount))
          _buildRow(item, formats, loc, onSurface),
        if (itemCount < widget.items.length)
          TextButton(
            onPressed: () => setState(() => _visibleCount += _pageSize),
            child: Text(loc.clickHereToSeeMore),
          ),
      ],
    );
  }

  Widget _buildRow(
    ModelInstitutional item,
    StockDisplayFormats formats,
    AppLocalizations loc,
    Color onSurface,
  ) {
    final foreignDiff = item.foreignDiff;
    final totalDiff = item.totalDiff;
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 20, color: onSurface),
        children: [
          TextSpan(text: '${item.stockNo.trim()} ${item.stockName.trim()} '),
          TextSpan(
            text: '${formats.quantity(foreignDiff / 1000)} ',
            style: TextStyle(
              color: widget.isBuy ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: '${loc.stockNet}: '),
          TextSpan(
            text: '${formats.quantity(totalDiff / 1000)} ',
            style: TextStyle(
              color: widget.isBuy
                  ? (foreignDiff < totalDiff ? Colors.red : Colors.blue)
                  : (foreignDiff > totalDiff ? Colors.green : Colors.blue),
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: loc.stockThousandLots),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/stock_display_formats.dart';
import 'package:life_pilot/stock/widgets_stock_section_failure.dart';
import 'package:life_pilot/utils/const.dart';

/// View-only futures section; its caller owns loading, filtering and retry.
class WidgetsStockFutures extends StatelessWidget {
  const WidgetsStockFutures({
    super.key,
    required this.items,
    required this.loading,
    required this.onRetry,
    this.error,
  });
  final List<ModelFuture> items;
  final bool loading;
  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final formats = StockDisplayFormats.forLocale(loc.localeName);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                loc.stockDashboardTitle,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            if (loading)
              const SizedBox.square(
                key: ValueKey('stock-futures-loading'),
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        Gaps.h8,
        if (error != null)
          WidgetsStockSectionFailure(error: error!, onRetry: onRetry),
        if (!loading && error == null && items.isEmpty) Text(loc.noData),
        ...items.map(
          (e) => RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 20, color: onSurface),
              children: [
                TextSpan(
                  text: "${e.productName?.trim()} ${e.identityType?.trim()} ",
                ),
                TextSpan(
                  text: '${formats.quantity(e.oiNetQty)} ',
                  style: TextStyle(
                    color: (e.oiNetQty ?? 0) >= 0 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(text: '${loc.stockNet}: '),
                TextSpan(
                  text: '${formats.quantity(e.oiNetQtyDiff)} ',
                  style: TextStyle(
                    color: (e.oiNetQtyDiff ?? 0) > 0
                        ? Colors.red
                        : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

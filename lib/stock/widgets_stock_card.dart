import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/stock_display_formats.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:url_launcher/url_launcher.dart';

/// View-only stock card. Loading, filtering and ranking belong to Controller/Model.
class WidgetsStockCard extends StatelessWidget {
  const WidgetsStockCard({super.key, required this.stock, required this.index});
  final ModelStock stock;
  final int index;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final formats = StockDisplayFormats.forLocale(loc.localeName);
    final colorScheme = Theme.of(context).colorScheme;
    final percent = stock.pctChange;
    final peRatio = stock.peRatio;
    final rsi = stock.rsi;
    final signal = stock.signal;
    final origin = stock.origin;
    final isUp = stock.change?.contains('+') == true || (percent ?? 0) > 0;
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
                  "https://tw.stock.yahoo.com/quote/${stock.securityCode}",
                );
                await launchUrl(url, mode: LaunchMode.externalApplication);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text("${index + 1}. "),
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
                          color: signal == 1
                              ? Colors.red
                              : (signal == -1
                                    ? Colors.green
                                    : colorScheme.onSurface),
                          fontWeight: signal != 0
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
                  loc.stockClosingPrice(formats.price(stock.closingPrice)),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (percent != null)
                  Text(
                    '${percent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: isUp ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (peRatio != null && peRatio != 0)
                  Text(loc.priceEarningsRatio(peRatio.toString())),
              ],
            ),
            Gaps.h8,

            /// 🔹 第三行：其他資訊
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (rsi != null)
                  Text(
                    loc.relativeStrengthIndex(rsi.toStringAsFixed(2)),
                    style: TextStyle(
                      color: rsi < 50 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Text(
                  loc.stockTradingVolume(
                    formats.quantity((stock.tradedNumber ?? 0) / 1000),
                  ),
                ),
              ],
            ),
            Gaps.h8,

            /// 🔹 第四行：其他資訊
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(formats.date(stock.date)),
                if (origin != null)
                  Text(
                    origin == StockDataOrigin.cloud
                        ? loc.stockSourceCloud
                        : loc.stockSourceBackend,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

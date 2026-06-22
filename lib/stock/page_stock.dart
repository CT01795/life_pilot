// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

          return ListView(
            padding: const EdgeInsets.all(8),
            children: [

              /// =========================
              /// 📊 DASHBOARD（放最上面）
              /// =========================
              _buildDashboard(controller),
              Gaps.h8,

              /// =========================
              /// 📈 STOCK LIST
              /// =========================
              for (int i = 0; i < controller.stocks.length; i++)
                _buildStockCard(controller.stocks[i], i),
            ],
          );
        },
      ),
    );
  }
}

Widget _buildDashboard(ControllerStock c) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "📊 市場儀表板",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      Gaps.h8,
      Text(
        "外資期貨：${NumberFormat('#,##0').format(c.foreignFuture?.oiNetQty ?? 0)}",
        style: TextStyle(
                        color: (c.foreignFuture?.oiNetQty?? 0) < 0 ? Colors.green : Colors.red),
      ),
      Text(
        "Diff：${NumberFormat('#,##0').format(c.foreignFuture?.oiNetQtyDiff ?? 0)}",
        style: TextStyle(
                        color: (c.foreignFuture?.oiNetQtyDiff?? 0) < 0 ? Colors.green : (c.foreignFuture?.oiNetQtyDiff?? 0) == 0 ? Colors.black: Colors.red),
      ),
      Gaps.h4,
      Text(
        "投信期貨：${NumberFormat('#,##0').format(c.trustFuture?.oiNetQty ?? 0)}",
        style: TextStyle(
                        color: (c.trustFuture?.oiNetQty?? 0) < 0 ? Colors.green : Colors.red),
      ),
      Text(
        "Diff：${NumberFormat('#,##0').format(c.trustFuture?.oiNetQtyDiff ?? 0)}",
        style: TextStyle(
                        color: (c.trustFuture?.oiNetQtyDiff?? 0) < 0 ? Colors.green : (c.trustFuture?.oiNetQtyDiff?? 0) == 0 ? Colors.black: Colors.red),
      ),
      Gaps.h4,
      Text(
        "自營商期貨：${NumberFormat('#,##0').format(c.dealerFuture?.oiNetQty ?? 0)}",
        style: TextStyle(
                        color: (c.dealerFuture?.oiNetQty?? 0) < 0 ? Colors.green : Colors.red),
      ),
      Text(
        "Diff：${NumberFormat('#,##0').format(c.dealerFuture?.oiNetQtyDiff ?? 0)}",
        style: TextStyle(
                        color: (c.dealerFuture?.oiNetQtyDiff?? 0) < 0 ? Colors.green : (c.dealerFuture?.oiNetQtyDiff?? 0) == 0 ? Colors.black : Colors.red),
      ),
      Gaps.h32,
      Text("外資買超 Top30"),
      ...c.foreignBuyTop30.take(30).map(
            (e) => Text("${e.stockNo} ${e.stockName} ${NumberFormat('#,##0').format(e.foreignDiff)}",
                    style: TextStyle(color: Colors.red)),
          ),
      Gaps.h8,
      Text("外資賣超 Top30"),
      ...c.foreignSellTop30.take(30).map(
            (e) => Text("${e.stockNo} ${e.stockName} ${NumberFormat('#,##0').format(e.foreignDiff)}",
                    style: TextStyle(color: Colors.green)),
          ),
    ],
  );
}

Widget _buildStockCard(ModelStock stock, int index) {
  bool isUp = stock.change != null && stock.change!.contains("+");
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔹 第一行：股號 + 名稱（可點擊）
            GestureDetector(
              onTap: () async {
                final url = Uri.parse(
                    "https://tw.stock.yahoo.com/quote/${stock.securityCode}");

                if (await canLaunchUrl(url)) {
                  await launchUrl(url,
                      mode: LaunchMode.externalApplication);
                }
              },
              child: Row(
                children: [
                  Text(
                    "${index + 1}. ",
                  ),
                  Gaps.w8,
                  Text(
                    stock.securityCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
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
                            : (stock.signal == -1 ? Colors.green : Colors.black),
                        fontWeight: stock.signal != 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Gaps.h8,

            /// 🔹 第二行：收盤價 + 漲跌
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "收盤價: ${NumberFormat('#,##0.00').format(stock.closingPrice)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Gaps.w8,
                Text(
                  "${stock.pctChange?.toStringAsFixed(2)}%",
                  style: TextStyle(
                    color: isUp || (stock.pctChange ?? 0) > 0? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Gaps.w8,
                if (stock.peRatio != null && stock.peRatio != 0)
                    Text("P/E: ${stock.peRatio}"),
              ],
            ),
            Gaps.h8,

            /// 🔹 第三行：其他資訊
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "RSI: ${stock.rsi?.toStringAsFixed(2)}",
                  style: TextStyle(
                    color: stock.rsi == null || stock.rsi! < 50
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Gaps.w8,
                Text(
                  "成交張數: ${NumberFormat('#,##0').format((stock.tradedNumber ?? 0) / 1000)}",
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

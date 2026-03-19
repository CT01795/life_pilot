// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/stock/controller_stock.dart';
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

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: controller.stocks.length,
            itemBuilder: (context, index) {
              final stock = controller.stocks[index];
              final changePercent =
                  (stock.priceDifference ?? 0) / stock.closingPrice * 100;

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
                                "${stock.securityName} ${stock.isRising == true ? "***" : ""}",
                                style: TextStyle(
                                  color: stock.isRising == true ? Colors.red : Colors.black,
                                  fontWeight: stock.isRising == true ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Gaps.h8,

                      /// 🔹 第二行：收盤價 + 漲跌
                      Row(
                        children: [
                          Text(
                            NumberFormat('#,##0.00')
                                .format(stock.closingPrice),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Gaps.w8,
                          Text(
                            "${changePercent.toStringAsFixed(2)}%",
                            style: TextStyle(
                              color: isUp ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Gaps.h8,
                      /// 🔹 第三行：其他資訊
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "成交張數: ${NumberFormat('#,##0').format((stock.tradedNumber ?? 0) / 1000)}",
                          ),
                          if (stock.peRatio != null && stock.peRatio != 0)
                            Text("P/E: ${stock.peRatio}"),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


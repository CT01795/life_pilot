// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:life_pilot/stock/controller_stock.dart';
import 'package:life_pilot/stock/service_stock.dart';
import 'package:provider/provider.dart';

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
            itemCount: controller.stocks.length,
            itemBuilder: (context, index) {
              final stock = controller.stocks[index];
              return ListTile(
                leading: Text("${index + 1}"),
                title: Text("(${stock.securityCode}) ${stock.securityName}"),
                trailing:
                    Text(stock.closingPrice.toStringAsFixed(2)),
              );
            },
          );
        },
      ),
    );
  }
}
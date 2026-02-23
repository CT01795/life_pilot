import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/accounting/controller_accounting_account.dart';
import 'package:life_pilot/controllers/accounting/controller_accounting.dart';
import 'package:life_pilot/controllers/accounting/controller_accounting_speech.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/accounting/model_accounting_account.dart';
import 'package:life_pilot/models/accounting/model_accounting_preview.dart';
import 'package:life_pilot/services/event/service_speech.dart';
import 'package:life_pilot/services/service_accounting.dart';
import 'package:provider/provider.dart';

class PageAccountingDetail extends StatelessWidget {
  final ModelAccountingAccount account;
  final String currentType;
  final ServiceAccounting service;
  const PageAccountingDetail({
    super.key,
    required this.service,
    required this.account,
    required this.currentType,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ControllerAccounting(
            service: service,
            accountController: context.read<ControllerAccountingAccount>(),
            auth: context.read<ControllerAuth>(),
            accountId: account.id,
            currentType: currentType,
          )..loadToday(),
        ),
        Provider<ControllerAccountingSpeech>(
          create: (_) => ControllerAccountingSpeech(),
        ),
      ],
      child: _PageAccountingDetailView(),
    );
  }
}

class _PageAccountingDetailView extends StatefulWidget {
  const _PageAccountingDetailView();

  @override
  State<_PageAccountingDetailView> createState() =>
      _PageAccountingDetailViewState();
}

class _PageAccountingDetailViewState extends State<_PageAccountingDetailView> {
  final TextEditingController _speechTextController = TextEditingController();
  final numberFormatter = NumberFormat('#,###');

  @override
  void dispose() {
    context.read<ServiceSpeech>().stopListening();
    _speechTextController.dispose();
    super.dispose();
  }

  Future<bool?> showVoiceConfirmDialog(
    BuildContext context,
    List<AccountingPreview> previews,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isValid = previews.every(
              (p) => p.value != 0 && p.description.trim().isNotEmpty,
            );
            return AlertDialog(
              title: const Text('Please confirm'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(previews.length, (index) {
                  final p = previews[index];
                  return ListTile(
                    dense: true,
                    onTap: () async {
                      // 點整個 ListTile 都能編輯
                      final updated = await _showEditDetailDialog(context, p);
                      if (updated != null) {
                        setState(() {
                          previews[index] = updated;
                        });
                      }
                    },
                    title: Text(p.description),
                    trailing: Text(
                      '${p.value >= 0 ? '+' : ''}${p.value} ${p.currency}',
                      style: TextStyle(
                        color: p.value >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      isValid ? () => Navigator.pop(context, true) : null,
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String formatRecordTime(DateTime time) {
    final now = DateTime.now();

    if (time.year == now.year) {
      return DateFormat('M/d HH:mm').format(time);
    } else {
      return DateFormat('yyyy/M/d HH:mm').format(time);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ControllerAccounting>();
    final account = controller.getAccount();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, true); // 返回上一頁並通知需要刷新
          },
        ),
        title: Text(account == null ? constEmpty : account.accountName),
        backgroundColor: Colors.blueAccent, // 可自定義顏色
        elevation: 2,
      ),
      body: Column(
        children: [
          Gaps.h8,
          _buildSummary(account, controller),
          _buildMicButton(context, controller),
          const Divider(),
          _buildTodayList(controller),
        ],
      ),
    );
  }

  Widget _buildSummary(
      ModelAccountingAccount? account, ControllerAccounting controller) {
    if (account == null) {
      return SizedBox.shrink(); // 返回一個不佔空間的 widget
    }
    String currency = account.currency ?? '';
    int totalValue = controller.totalValue;

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: IntrinsicColumnWidth(), // 左文字自動寬度
        1: IntrinsicColumnWidth(), // 幣別自動寬度
        2: IntrinsicColumnWidth(), // 數值自動寬度
      },
      children: [
        TableRow(
          children: [
            Text(' Total ', style: const TextStyle(fontSize: 20)),
            controller.currentType == 'balance' && account.currency != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(currency, style: const TextStyle(fontSize: 20)),
                  )
                : const SizedBox(),
            Text(
              '${NumberFormat('#,###').format(totalValue)} ${controller.currentType == 'balance' ? '元' : '分'}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: totalValue >= 0 ? Colors.black : Colors.red,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ),
        TableRow(
          children: [
            Text(' Today ', style: const TextStyle(fontSize: 20)),
            controller.currentType == 'balance' && account.currency != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(currency, style: const TextStyle(fontSize: 20)),
                  )
                : const SizedBox(),
            Text(
              '${NumberFormat('#,###').format(controller.todayTotal)} ${controller.currentType == 'balance' ? '元' : '分'}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: controller.todayTotal >= 0 ? Colors.green : Colors.red,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTodayList(ControllerAccounting controller) {
    return Expanded(
      child: ListView.builder(
        itemCount: controller.todayRecords.length,
        itemBuilder: (context, index) {
          final record = controller.todayRecords[index];
          return ListTile(
            key: ValueKey(record.id),
            title: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "${record.displayTime}  ",
                    style: TextStyle(fontSize: 12, color: Colors.grey), // 時間小一點
                  ),
                  TextSpan(
                    text: record.description,
                    style: TextStyle(color: Colors.black), // 描述正常大小
                  ),
                ],
              ),
            ),
            trailing: Text(
              record.value > 0
                  ? '+${numberFormatter.format(record.value)} ${record.currency}'
                  : '${numberFormatter.format(record.value)} ${record.currency}',
              style: TextStyle(
                  color: record.value >= 0 ? Colors.green : Colors.red,
                  fontSize: 18),
            ),
            onTap: () async {
              final updated = await _showEditDetailDialog(
                context,
                AccountingPreview(
                  id: record.id,
                  description: record.description,
                  value: record.value,
                  currency: record.currency,
                  exchangeRate: null,
                ),
              );
              if (updated != null) {
                await controller.updateAccountingDetail(
                  recordId: updated.id,
                  newValue: updated.value,
                  newCurrency: updated.currency,
                  newDescription: updated.description,
                );
                await controller.loadToday();
                final ctrlAA = context.read<ControllerAccountingAccount>();
                await ctrlAA.loadAccounts(force: true);
                //setState(() {});
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildMicButton(
      BuildContext context, ControllerAccounting controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 麥克風按鈕
          FloatingActionButton(
            child: const Icon(Icons.mic, size: 50),
            onPressed: () async {
              final speechController =
                  context.read<ControllerAccountingSpeech>();
              final text = await speechController.recordAndTranscribe();
              if (text.isNotEmpty) {
                setState(() {
                  _speechTextController.text = text;
                });
              }
            },
          ),
          Gaps.w8,
          // 可編輯文字欄位
          Expanded(
            child: TextField(
              controller: _speechTextController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '...加/扣...元',
              ),
              maxLines: 1,
            ),
          ),
          Gaps.w8,
          ElevatedButton(
            onPressed: () async {
              if (_speechTextController.text.isEmpty) return;
              final previews = await controller.parseFromSpeech(
                  _speechTextController.text,
                  controller.currentCurrency,
                  controller.currentExchangeRate);
              if (previews.isEmpty) return;
              final confirmed = await showVoiceConfirmDialog(context, previews);
              if (confirmed != true) return;
              await controller.commitRecords(
                  previews, controller.currentCurrency);
              final ctrlAA = context.read<ControllerAccountingAccount>();
              await ctrlAA.loadAccounts(force: true);

              // 清空輸入框
              setState(() {
                _speechTextController.clear();
              });
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  // 回傳修改後的 AccountingPreview，取消則回傳 null
  Future<AccountingPreview?> _showEditDetailDialog(
      BuildContext context, AccountingPreview record) async {
    final valueController =
        TextEditingController(text: record.value.toString());
    final descController = TextEditingController(text: record.description);
    String currency = record.currency ?? '';

    final result = await showDialog<AccountingPreview>(
      context: context,
      builder: (context) {
        // ✅ 使用 StatefulBuilder 來控制 dialog 內的狀態
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Record'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  TextField(
                    controller: valueController,
                    decoration: const InputDecoration(labelText: 'Value'),
                    keyboardType: TextInputType.number,
                  ),
                  DropdownButton<String>(
                    value: currency,
                    isExpanded: true,
                    items: currencyList
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          currency = val; // ✅ 正確更新幣別
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final v = int.tryParse(valueController.text);
                    if (v == null || descController.text.trim().isEmpty) return;
                    Navigator.pop(
                      context,
                      record.copyWith(
                        value: v,
                        description: descController.text.trim(),
                        currency: currency,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }
}

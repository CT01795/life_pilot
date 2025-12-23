import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/point_record/controller_point_record.dart';
import 'package:life_pilot/controllers/point_record/controller_point_record_account.dart';
import 'package:life_pilot/controllers/point_record/controller_point_record_speech.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/point_record/model_point_record_account.dart';
import 'package:life_pilot/models/point_record/model_point_record_preview.dart';
import 'package:life_pilot/services/service_point_record.dart';
import 'package:provider/provider.dart';

class PagePointRecordDetail extends StatefulWidget {
  final String accountId;
  final String accountName;
  final ServicePointRecord service;

  const PagePointRecordDetail({
    super.key,
    required this.service,
    required this.accountId,
    required this.accountName,
  });

  @override
  State<PagePointRecordDetail> createState() => _PagePointRecordDetailState();
}

class _PagePointRecordDetailState extends State<PagePointRecordDetail> {
  late final TextEditingController _speechTextController;
  late ControllerPointRecord _controller;
  final numberFormatter = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _speechTextController = TextEditingController();
    _controller = ControllerPointRecord(
      widget.service,
      widget.accountId,
      context.read<ControllerPointRecordAccount>(),
    );

  _controller.loadToday(); // ✅ 只載一次
  }

  @override
  void dispose() {
    _speechTextController.dispose();
    super.dispose();
  }

  Future<bool?> showVoiceConfirmDialog(
    BuildContext context,
    List<PointRecordPreview> previews,
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
                    title: InkWell(
                      onTap: () async {
                        final controller =
                            TextEditingController(text: p.description);

                        final result = await showDialog<String>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Edit description'),
                            content: TextField(controller: controller),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, null),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.pop(context, controller.text),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );

                        if (result != null && result.trim().isNotEmpty) {
                          setState(() {
                            previews[index] = p.copyWith(
                              description: result.trim(),
                            );
                          });
                        }
                      },
                      child: Text(p.description),
                    ),
                    trailing: _EditableValue(
                      value: p.value,
                      onChanged: (newValue) {
                        setState(() {
                          previews[index] = p.copyWith(value: newValue);
                        });
                      },
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
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, true); // 返回上一頁並通知需要刷新
            },
          ),
          title: Text(widget.accountName),
          backgroundColor: Colors.blueAccent, // 可自定義顏色
          elevation: 2,
        ),
        body: Consumer2<ControllerPointRecord, ControllerPointRecordAccount>(
          builder: (context, pointsController, accountController, _) {
            final account = accountController.getAccountById(widget.accountId);
            return Column(
              children: [
                Gaps.h8,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Points'),
                      selected: pointsController.currentType == 'points',
                      onSelected: (_) async {
                        await pointsController.switchType('points');
                      },
                    ),
                    Gaps.w16,
                    ChoiceChip(
                      label: const Text('Balance'),
                      selected: pointsController.currentType == 'balance',
                      onSelected: (_) async {
                        await pointsController.switchType('balance');
                      },
                    ),
                  ],
                ),
                _buildSummary(account, pointsController),
                _buildMicButton(context, pointsController),
                const Divider(),
                _buildTodayList(pointsController),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummary(
      ModelPointRecordAccount account, ControllerPointRecord controller) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Text('Today ${controller.currentType}：${numberFormatter.format(controller.todayTotal)}',
              style: const TextStyle(fontSize: 20)),
        ],
      ),
    );
  }

  Widget _buildTodayList(ControllerPointRecord controller) {
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
              record.value > 0 ? '+${numberFormatter.format(record.value)}' : numberFormatter.format(record.value),
              style: TextStyle(
                color: record.value >= 0 ? Colors.green : Colors.red,
                fontSize: 18
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMicButton(
      BuildContext context, ControllerPointRecord controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 麥克風按鈕
          FloatingActionButton(
            child: const Icon(Icons.mic, size: 50),
            onPressed: () async {
              final speechController =
                  context.read<ControllerPointRecordSpeech>();
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
                hintText: 'Input',
              ),
              maxLines: 1,
            ),
          ),
          Gaps.w8,
          ElevatedButton(
            onPressed: () async {
              if (_speechTextController.text.isEmpty) return;
              final previews = await controller
                  .parseFromSpeech(_speechTextController.text);
              if (previews.isEmpty) return;
              final confirmed = await showVoiceConfirmDialog(context, previews);
              if (confirmed != true) return;

              final tts = context.read<TtsService>();
              await controller.commitRecords(previews);
              // ❶ 取這次變動的總值
              final delta = previews.fold<int>(0, (sum, p) => sum + p.value);
              // ❷ 更新主頁帳戶
              final accountController = context.read<ControllerPointRecordAccount>();
              if (controller.currentType == 'points') {
                accountController.updateAccountTotals(
                  accountId: controller.account.id,
                  deltaPoints: delta,
                  deltaBalance: 0,
                );
              } else {
                accountController.updateAccountTotals(
                  accountId: controller.account.id,
                  deltaPoints: 0,
                  deltaBalance: delta,
                );
              }

              final summary = previews.map((p) {
                final v = p.value;
                return '${p.description}${v > 0 ? '加$v' : '扣${v.abs()}'}';
              }).join('，');

              await tts.speak('${previews.length} records created, $summary');

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
}

class _EditableValue extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _EditableValue({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final controller = TextEditingController(text: value.abs().toString());

        final result = await showDialog<int>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Edit value'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final v = int.tryParse(controller.text);
                  if (v != null) {
                    Navigator.pop(context, value >= 0 ? v : -v);
                  }
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );

        if (result != null) {
          onChanged(result);
        }
      },
      child: Text(
        value > 0 ? '+$value' : value.toString(),
        style: TextStyle(
          color: value >= 0 ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class TtsService {
  final FlutterTts _tts = FlutterTts();

  Future<void> speak(String text) async {
    await _tts.setLanguage('zh-TW');
    await _tts.setSpeechRate(0.45);
    await _tts.speak(text);
  }
}

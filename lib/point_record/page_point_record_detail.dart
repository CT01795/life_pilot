import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/controller_speech.dart';
import 'package:life_pilot/point_record/controller_point_record_detail.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/model_point_record_preview.dart';
import 'package:life_pilot/utils/service/service_speech.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/record_categories.dart';
import 'package:provider/provider.dart';

class PagePointRecordDetail extends StatelessWidget {
  final ModelPointRecordAccount account;
  final ServicePointRecord service;

  const PagePointRecordDetail({
    super.key,
    required this.service,
    required this.account,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProxyProvider<ControllerAuth,
            ControllerPointRecordDetail>(
          create: (context) => ControllerPointRecordDetail(
            service: service,
            auth: context.read<ControllerAuth>(),
            accountId: account.id,
          ),
          update: (_, auth, controller) {
            controller ??= ControllerPointRecordDetail(
              service: service,
              auth: auth,
              accountId: account.id,
            );
            controller.auth = auth;
            return controller;
          },
        ),
        Provider<ControllerSpeech>(
          create: (_) => ControllerSpeech(),
        ),
        Provider<ServiceSpeech>(
          create: (_) => ServiceSpeech(),
        ),
      ],
      child: _PagePointRecordDetailView(account),
    );
  }
}

class _PagePointRecordDetailView extends StatefulWidget {
  final ModelPointRecordAccount account;
  const _PagePointRecordDetailView(this.account);

  @override
  State<_PagePointRecordDetailView> createState() =>
      _PagePointRecordDetailViewState();
}

class _PagePointRecordDetailViewState
    extends State<_PagePointRecordDetailView> {
  late ServiceSpeech _speechService;
  final TextEditingController _speechTextController = TextEditingController();
  final numberFormatter = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<ControllerPointRecordDetail>()
          .loadToday(inputAccountId: widget.account.id);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _speechService = context.read<ServiceSpeech>();
  }

  @override
  void dispose() {
    _speechService.stopListening();
    _speechTextController.dispose();
    super.dispose();
  }

  Future<bool?> showVoiceConfirmDialog(
    BuildContext context,
    List<PointRecordPreview> previews,
  ) {
    final loc = AppLocalizations.of(context)!;
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
              title: Text(loc.recordPleaseConfirm),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(previews.length, (index) {
                  final p = previews[index];
                  return ListTile(
                    dense: true,
                    onTap: () async {
                      final updated = await _showEditDetailDialog(context, p);
                      if (updated != null) {
                        setState(() => previews[index] = updated);
                      }
                    },
                    title: Text(p.description),
                    subtitle: Text(
                      RecordCategories.label(
                        AppLocalizations.of(context)!,
                        p.primaryCategory,
                      ),
                    ),
                    trailing: Text(
                      p.value > 0 ? '+${p.value}' : p.value.toString(),
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
                  child: Text(loc.cancel),
                ),
                ElevatedButton(
                  onPressed:
                      isValid ? () => Navigator.pop(context, true) : null,
                  child: Text(loc.confirm),
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
    final controller = context.watch<ControllerPointRecordDetail>();
    final account = widget.account;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, true); // 返回上一頁並通知需要刷新
          },
        ),
        title: Text(account.accountName),
        backgroundColor: Colors.blueAccent, // 可自定義顏色
        elevation: 2,
      ),
      body: Column(
        children: [
          Gaps.h8,
          _buildSummary(context, account, controller),
          _buildMicButton(context, controller),
          const Divider(),
          _buildTodayList(controller),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, ModelPointRecordAccount account,
      ControllerPointRecordDetail controller) {
    final loc = AppLocalizations.of(context)!;
    int totalValue = controller.total ?? 0;
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
            Text(' ${loc.recordTotal} ', style: const TextStyle(fontSize: 20)),
            Text(
              '${NumberFormat('#,###').format(totalValue)} ${loc.pointsUnit}'
                  .trim(),
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
            Text(' ${loc.today} ', style: const TextStyle(fontSize: 20)),
            Text(
              '${NumberFormat('#,###').format(controller.todayTotal)} ${loc.pointsUnit}'
                  .trim(),
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

  Widget _buildTodayList(ControllerPointRecordDetail controller) {
    final visibleRecords = controller.todayRecords
        .where((record) => record.id.isNotEmpty)
        .toList();
    return Expanded(
      child: ListView.builder(
        itemCount: visibleRecords.length,
        itemBuilder: (context, index) {
          final record = visibleRecords[index];
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
                    text:
                        '[${RecordCategories.label(AppLocalizations.of(context)!, record.primaryCategory)}]  ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
                  ? '+${numberFormatter.format(record.value)}'
                  : numberFormatter.format(record.value),
              style: TextStyle(
                  color: record.value >= 0 ? Colors.green : Colors.red,
                  fontSize: 18),
            ),
            onTap: () async {
              final updated = await _showEditDetailDialog(
                context,
                PointRecordPreview(
                  id: record.id,
                  description: record.description,
                  value: record.value,
                  date: record.localTime,
                  primaryCategory: record.primaryCategory,
                  secondaryCategory: record.secondaryCategory,
                ),
              );
              if (updated != null) {
                await controller.updatePointRecordDetail(updated);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildMicButton(
      BuildContext context, ControllerPointRecordDetail controller) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 麥克風按鈕
          FloatingActionButton(
            child: const Icon(Icons.mic, size: 50),
            onPressed: () async {
              final speechController = context.read<ControllerSpeech>();
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
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: loc.pointsSpeechHint,
              ),
              maxLines: 1,
            ),
          ),
          Gaps.w8,
          ElevatedButton(
            onPressed: () async {
              if (_speechTextController.text.isEmpty) return;
              final previews =
                  controller.parseFromSpeech(_speechTextController.text);
              if (previews.isEmpty) return;
              final confirmed = await showVoiceConfirmDialog(context, previews);
              if (confirmed != true) return;

              await controller.commitRecords(previews);

              // 清空輸入框
              setState(() {
                _speechTextController.clear();
              });
            },
            child: Text(loc.recordSubmit),
          ),
        ],
      ),
    );
  }

  Future<PointRecordPreview?> _showEditDetailDialog(
    BuildContext context,
    PointRecordPreview record,
  ) async {
    final valueController =
        TextEditingController(text: record.value.toString());
    final descController = TextEditingController(text: record.description);
    DateTime selectedDate = record.date ?? DateTime.now();
    String primaryCategory = record.primaryCategory;
    final secondaryController =
        TextEditingController(text: record.secondaryCategory ?? '');
    final loc = AppLocalizations.of(context)!;

    return showDialog<PointRecordPreview>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(loc.editRecord),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descController,
                  decoration: InputDecoration(labelText: loc.description),
                ),
                TextField(
                  controller: valueController,
                  decoration: InputDecoration(labelText: loc.recordValue),
                  keyboardType: TextInputType.number,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(loc.recordDate),
                  subtitle: Text(
                    DateFormat.yMd(Localizations.localeOf(context).toString())
                        .format(selectedDate),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          selectedDate.hour,
                          selectedDate.minute,
                          selectedDate.second,
                        );
                      });
                    }
                  },
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue:
                      RecordCategories.points.contains(primaryCategory)
                          ? primaryCategory
                          : RecordCategories.uncategorized,
                  decoration:
                      InputDecoration(labelText: loc.recordPrimaryCategory),
                  items: RecordCategories.points
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(RecordCategories.label(loc, category)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) primaryCategory = value;
                  },
                ),
                TextField(
                  controller: secondaryController,
                  decoration:
                      InputDecoration(labelText: loc.recordSecondaryCategory),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final value = int.tryParse(valueController.text);
                final description = descController.text.trim();
                if (value == null || description.isEmpty) return;
                Navigator.pop(
                  context,
                  record.copyWith(
                    value: value,
                    description: description,
                    date: selectedDate,
                    primaryCategory: primaryCategory,
                    secondaryCategory: secondaryController.text.trim(),
                  ),
                );
              },
              child: Text(loc.save),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:intl/intl.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/controller_speech.dart';
import 'package:life_pilot/point_record/controller_point_record_detail.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/model_point_record_detail.dart';
import 'package:life_pilot/point_record/model_point_record_preview.dart';
import 'package:life_pilot/utils/service/service_speech.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/record_categories.dart';
import 'package:life_pilot/utils/record_date_time.dart';
import 'package:life_pilot/utils/record_filter.dart';
import 'package:life_pilot/utils/widgets/widgets_record_explorer.dart';
import 'package:life_pilot/utils/widgets/widgets_record_input.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/subscription/widgets_subscription_usage.dart';

class PagePointRecordDetail extends StatelessWidget {
  final ModelPointRecordAccount account;
  final ServicePointRecord service;
  final bool returnAfterSubmit;
  final String? linkedEventId;

  const PagePointRecordDetail({
    super.key,
    required this.service,
    required this.account,
    this.returnAfterSubmit = false,
    this.linkedEventId,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProxyProvider<
          ControllerAuth,
          ControllerPointRecordDetail
        >(
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
            controller.updateAuth(auth, notify: false);
            return controller;
          },
        ),
        Provider<ControllerSpeech>(create: (_) => ControllerSpeech()),
        Provider<ServiceSpeech>(create: (_) => ServiceSpeech()),
      ],
      child: _PagePointRecordDetailView(
        account,
        returnAfterSubmit,
        linkedEventId,
      ),
    );
  }
}

class _PagePointRecordDetailView extends StatefulWidget {
  final ModelPointRecordAccount account;
  final bool returnAfterSubmit;
  final String? linkedEventId;
  const _PagePointRecordDetailView(
    this.account,
    this.returnAfterSubmit,
    this.linkedEventId,
  );

  @override
  State<_PagePointRecordDetailView> createState() =>
      _PagePointRecordDetailViewState();
}

class _PagePointRecordDetailViewState
    extends State<_PagePointRecordDetailView> {
  late ServiceSpeech _speechService;
  final TextEditingController _speechTextController = TextEditingController();
  final TextEditingController _recordSearchController = TextEditingController();
  final numberFormatter = NumberFormat('#,###');
  DateTime _newRecordDate = DateTime.now();
  String _recordSearchQuery = '';
  String? _selectedRecordCategory;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ControllerPointRecordDetail>().loadToday(
        inputAccountId: widget.account.id,
      );
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
    _recordSearchController.dispose();
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
              scrollable: true,
              title: Text(loc.recordPleaseConfirm),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(previews.length, (index) {
                  final p = previews[index];
                  final recordDate = p.date ?? _newRecordDate;
                  final category = RecordCategories.label(
                    loc,
                    p.primaryCategory,
                  );
                  final dateText = DateFormat.yMd(
                    Localizations.localeOf(context).toString(),
                  ).format(recordDate);
                  final timeText = MaterialLocalizations.of(
                    context,
                  ).formatTimeOfDay(TimeOfDay.fromDateTime(recordDate));
                  return ListTile(
                    dense: true,
                    isThreeLine: true,
                    onTap: () async {
                      final updated = await _showEditDetailDialog(context, p);
                      if (updated != null) {
                        setState(() => previews[index] = updated);
                      }
                    },
                    title: Row(
                      children: [
                        Expanded(child: Text(p.description)),
                        Gaps.w8,
                        Text(
                          p.value > 0 ? '+${p.value}' : p.value.toString(),
                          style: TextStyle(
                            color: p.value >= 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '$category\n${loc.recordDate}: $dateText · '
                      '${loc.recordTime}: $timeText',
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
                  onPressed: isValid
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: Text(loc.confirm),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ControllerPointRecordDetail>();
    final account = widget.account;
    final loc = AppLocalizations.of(context)!;
    final loadedRecords = controller.todayRecords
        .where((record) => record.id.isNotEmpty)
        .toList(growable: false);
    final visibleRecords = _filterRecords(loadedRecords, loc);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, true); // 返回上一頁並通知需要刷新
          },
        ),
        title: Text(account.accountName),
      ),
      body: CustomScrollView(
        scrollCacheExtent: const ScrollCacheExtent.pixels(240),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Gaps.h8,
                const SubscriptionUsageBanner(resource: 'point_record_detail'),
                _buildSummary(context, account, controller),
                _buildNewRecordDatePicker(context),
                _buildMicButton(context, controller),
                _buildRecordExplorer(context, loadedRecords, visibleRecords),
                const Divider(),
              ],
            ),
          ),
          _buildTodayList(controller, visibleRecords),
        ],
      ),
    );
  }

  List<ModelPointRecordDetail> _filterRecords(
    List<ModelPointRecordDetail> records,
    AppLocalizations loc,
  ) => filterRecordItems(
    records,
    query: _recordSearchQuery,
    selectedCategory: _selectedRecordCategory,
    descriptionOf: (record) => record.description,
    primaryCategoryOf: (record) => record.primaryCategory,
    secondaryCategoryOf: (record) => record.secondaryCategory,
    categoryLabelOf: (category) => RecordCategories.label(loc, category),
  );

  Widget _buildRecordExplorer(
    BuildContext context,
    List<ModelPointRecordDetail> loadedRecords,
    List<ModelPointRecordDetail> visibleRecords,
  ) {
    final loc = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final increase = visibleRecords
        .where((record) => record.value > 0)
        .fold<int>(0, (sum, record) => sum + record.value);
    final decrease = visibleRecords
        .where((record) => record.value < 0)
        .fold<int>(0, (sum, record) => sum + record.value.abs());
    final net = increase - decrease;
    final presentCategories = loadedRecords
        .map((record) => record.primaryCategory)
        .toSet();
    String metricValue(int value) =>
        '${numberFormatter.format(value)} ${loc.pointsUnit}'.trim();

    return WidgetsRecordExplorer(
      searchController: _recordSearchController,
      searchHint: loc.recordSearchHint,
      clearTooltip: loc.clear,
      categories: [
        RecordCategoryFilterOption(value: null, label: loc.recordAllCategories),
        for (final category in RecordCategories.points)
          if (presentCategories.contains(category))
            RecordCategoryFilterOption(
              value: category,
              label: RecordCategories.label(loc, category),
            ),
      ],
      selectedCategory: _selectedRecordCategory,
      onSearchChanged: (value) => setState(() => _recordSearchQuery = value),
      onCategorySelected: (value) =>
          setState(() => _selectedRecordCategory = value),
      metrics: [
        RecordExplorerMetric(
          icon: Icons.add_circle_outline,
          label: loc.eventPointIncrease,
          value: metricValue(increase),
          color: Colors.green,
        ),
        RecordExplorerMetric(
          icon: Icons.remove_circle_outline,
          label: loc.eventPointDecrease,
          value: metricValue(decrease),
          color: colors.error,
        ),
        RecordExplorerMetric(
          icon: Icons.swap_vert,
          label: loc.recordNetChange,
          value: metricValue(net),
          color: net < 0 ? colors.error : colors.primary,
        ),
      ],
    );
  }

  Widget _buildSummary(
    BuildContext context,
    ModelPointRecordAccount account,
    ControllerPointRecordDetail controller,
  ) {
    final loc = AppLocalizations.of(context)!;
    int totalValue = controller.total ?? 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(2)},
            children: [
              TableRow(
                children: [
                  Text(
                    ' ${loc.recordTotal} ',
                    style: const TextStyle(fontSize: 20),
                  ),
                  Text(
                    '${NumberFormat('#,###').format(totalValue)} ${loc.pointsUnit}'
                        .trim(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: totalValue >= 0
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.red,
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
                      color: controller.todayTotal >= 0
                          ? Colors.green
                          : Colors.red,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayList(
    ControllerPointRecordDetail controller,
    List<ModelPointRecordDetail> visibleRecords,
  ) {
    return SliverList.builder(
      addAutomaticKeepAlives: false,
      itemCount:
          visibleRecords.length +
          ((controller.hasMore || controller.isLoadingMore) ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == visibleRecords.length) {
          return Center(
            child: controller.isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  )
                : TextButton(
                    onPressed: () =>
                        controller.loadMore(inputAccountId: widget.account.id),
                    child: Text(
                      AppLocalizations.of(context)!.clickHereToSeeMore,
                    ),
                  ),
          );
        }
        final record = visibleRecords[index];
        return ListTile(
          key: ValueKey(record.id),
          title: Text(
            record.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Expanded(
                child: Text(
                  '${record.displayTime}  '
                  '[${RecordCategories.label(AppLocalizations.of(context)!, record.primaryCategory)}]',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Gaps.w8,
              Flexible(
                child: Text(
                  record.value > 0
                      ? '+${numberFormatter.format(record.value)}'
                      : numberFormatter.format(record.value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: record.value >= 0 ? Colors.green : Colors.red,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          trailing: IconButton(
            tooltip: AppLocalizations.of(context)!.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteRecord(controller, record.id),
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
    );
  }

  Future<void> _deleteRecord(
    ControllerPointRecordDetail controller,
    String detailId,
  ) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(loc.confirmDelete),
            content: Text(loc.subscriptionDeleteRecordHint),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(loc.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(loc.delete),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await controller.deletePointRecordDetail(detailId);
  }

  Widget _buildNewRecordDatePicker(BuildContext context) {
    return WidgetsRecordDateTimePicker(
      value: _newRecordDate,
      onChanged: (value) => setState(() => _newRecordDate = value),
    );
  }

  Widget _buildMicButton(
    BuildContext context,
    ControllerPointRecordDetail controller,
  ) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => _addManualRecord(context, controller),
              icon: const Icon(Icons.edit_outlined),
              label: Text(loc.manualEntry),
            ),
          ),
          Gaps.h8,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 麥克風按鈕
                    FloatingActionButton(
                      tooltip: loc.pointsSpeechExample,
                      child: const Icon(Icons.mic_rounded, size: 30),
                      onPressed: () async {
                        final speechController = context
                            .read<ControllerSpeech>();
                        final text = await speechController
                            .recordAndTranscribe();
                        if (text.isNotEmpty) {
                          setState(() {
                            _speechTextController.text = text;
                          });
                        }
                      },
                    ),
                    Gaps.w12,
                    // 可編輯文字欄位
                    Expanded(
                      child: TextField(
                        controller: _speechTextController,
                        autofocus: widget.returnAfterSubmit,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: loc.pointsSpeechHint,
                          alignLabelWithHint: true,
                        ),
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        minLines: 2,
                        maxLines: null,
                      ),
                    ),
                  ],
                ),
                Gaps.h12,
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.send_rounded),
                    onPressed: () async {
                      if (_speechTextController.text.isEmpty) return;
                      final latest = firstRecordOutsideCategory(
                        controller.todayRecords,
                        excludedCategory: RecordCategories.reserved,
                        primaryCategoryOf: (record) => record.primaryCategory,
                      );
                      final previews = controller.parseFromSpeech(
                        _speechTextController.text,
                      );
                      for (final preview in previews) {
                        preview.eventId = widget.linkedEventId;
                        preview.date = _newRecordDate;
                        preview.primaryCategory =
                            latest?.primaryCategory ??
                            RecordCategories.uncategorized;
                        preview.secondaryCategory = latest?.secondaryCategory;
                      }
                      if (previews.isEmpty) return;
                      final confirmed = await showVoiceConfirmDialog(
                        context,
                        previews,
                      );
                      if (confirmed != true) return;

                      try {
                        await controller.commitRecords(previews);
                      } catch (error) {
                        if (!context.mounted) return;
                        final message = subscriptionErrorMessage(loc, error);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              message.isEmpty ? loc.unknownError : message,
                            ),
                          ),
                        );
                        return;
                      }

                      // 清空輸入框
                      setState(() {
                        _speechTextController.clear();
                        _newRecordDate = DateTime.now();
                      });
                      if (widget.returnAfterSubmit && mounted) {
                        Navigator.of(context).pop(true);
                      }
                    },
                    label: Text(
                      loc.recordSubmit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addManualRecord(
    BuildContext context,
    ControllerPointRecordDetail controller,
  ) async {
    final latest = firstRecordOutsideCategory(
      controller.todayRecords,
      excludedCategory: RecordCategories.reserved,
      primaryCategoryOf: (record) => record.primaryCategory,
    );
    final draft = PointRecordPreview(
      description: '',
      value: latest?.value ?? 1,
      eventId: widget.linkedEventId,
      date: _newRecordDate,
      primaryCategory:
          latest?.primaryCategory ?? RecordCategories.uncategorized,
      secondaryCategory: latest?.secondaryCategory,
    );
    final record = await _showEditDetailDialog(context, draft, isNew: true);
    if (record == null) return;
    try {
      await controller.commitRecords([record]);
    } catch (error) {
      if (!context.mounted) return;
      final loc = AppLocalizations.of(context)!;
      final message = subscriptionErrorMessage(loc, error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.isEmpty ? loc.unknownError : message)),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _newRecordDate = DateTime.now());
    if (widget.returnAfterSubmit) Navigator.of(context).pop(true);
  }

  Future<PointRecordPreview?> _showEditDetailDialog(
    BuildContext context,
    PointRecordPreview record, {
    bool isNew = false,
  }) async {
    bool isPositive = record.value >= 0;
    final valueController = TextEditingController(
      text: isNew ? '' : record.value.abs().toString(),
    );
    final descController = TextEditingController(text: record.description);
    DateTime selectedDate = record.date ?? DateTime.now();
    String primaryCategory = record.primaryCategory;
    final secondaryController = TextEditingController(
      text: record.secondaryCategory ?? '',
    );
    final loc = AppLocalizations.of(context)!;

    return showDialog<PointRecordPreview>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isNew ? loc.manualEntry : loc.editRecord),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text(loc.eventPointIncrease),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.remove_circle_outline),
                      label: Text(loc.eventPointDecrease),
                    ),
                  ],
                  selected: {isPositive},
                  onSelectionChanged: (value) {
                    if (value.isEmpty) return;
                    setState(() => isPositive = value.first);
                  },
                ),
                Gaps.h8,
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
                    DateFormat.yMd(
                      Localizations.localeOf(context).toString(),
                    ).format(selectedDate),
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
                        selectedDate = replaceRecordDate(selectedDate, picked);
                      });
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: Text(loc.recordTime),
                  subtitle: Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatTimeOfDay(TimeOfDay.fromDateTime(selectedDate)),
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(selectedDate),
                    );
                    if (picked == null) return;
                    setState(() {
                      selectedDate = replaceRecordTime(selectedDate, picked);
                    });
                  },
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue:
                      RecordCategories.points.contains(primaryCategory)
                      ? primaryCategory
                      : RecordCategories.uncategorized,
                  decoration: InputDecoration(
                    labelText: loc.recordPrimaryCategory,
                  ),
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
                  decoration: InputDecoration(
                    labelText: loc.recordSecondaryCategory,
                  ),
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
                if (value == null || value <= 0 || description.isEmpty) return;
                Navigator.pop(
                  context,
                  record.copyWith(
                    value: isPositive ? value : -value,
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

import 'package:flutter/material.dart';
import 'package:life_pilot/utils/widgets/widgets_ledger_record_tile.dart';
import 'package:life_pilot/record_statistics/widgets_record_totals.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/record_statistics/model_record_explorer_metrics.dart';
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
import 'package:life_pilot/point_record/widgets_point_record_record_dialog.dart';
import 'package:life_pilot/utils/record_filter.dart';
import 'package:life_pilot/utils/widgets/widgets_record_explorer.dart';
import 'package:life_pilot/utils/widgets/widgets_record_input.dart';
import 'package:life_pilot/utils/widgets/widgets_record_preview_tile.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/subscription/widgets_subscription_usage.dart';

class PagePointRecordDetail extends StatelessWidget {
  final ModelPointRecordAccount account;
  final ServicePointRecord service;
  final bool returnAfterSubmit;
  final VoidCallback? onRecordsChanged;
  final String? linkedEventId;

  const PagePointRecordDetail({
    super.key,
    required this.service,
    required this.account,
    this.returnAfterSubmit = false,
    this.onRecordsChanged,
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
            onRecordsChanged: onRecordsChanged,
          ),
          update: (_, auth, controller) {
            controller ??= ControllerPointRecordDetail(
              service: service,
              auth: auth,
              accountId: account.id,
              onRecordsChanged: onRecordsChanged,
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
                  return WidgetsRecordPreviewTile(
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
          tooltip: loc.back,
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
    final metrics = ModelRecordExplorerMetrics.from<ModelPointRecordDetail>(
      visibleRecords,
      valueOf: (record) => record.value,
    );
    final net = metrics.net.toInt();
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
          value: metricValue(metrics.positive.toInt()),
          color: Colors.green,
        ),
        RecordExplorerMetric(
          icon: Icons.remove_circle_outline,
          label: loc.eventPointDecrease,
          value: metricValue(metrics.negativeMagnitude.toInt()),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: WidgetsRecordTotals(
            accountId: account.id,
            accountName: account.accountName,
            kind: RecordStatisticsKind.points,

            total: controller.total ?? account.points,
            revision: controller.todayRecords,
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
        return WidgetsLedgerRecordTile(
          key: ValueKey(record.id),
          description: record.description,
          displayTime: record.displayTime,
          primaryCategory: record.primaryCategory,
          value: record.value,
          formatter: numberFormatter,
          onDelete: () => _deleteRecord(controller, record.id),
          onEdit: () async {
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
                      final latest = firstRecordOutsideCategory(
                        controller.todayRecords,
                        excludedCategory: RecordCategories.reserved,
                        primaryCategoryOf: (record) => record.primaryCategory,
                      );
                      final List<PointRecordPreview> previews;
                      try {
                        previews = controller.parseFromSpeech(
                          _speechTextController.text,
                        );
                      } on FormatException {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(loc.pointRecordTextInvalid)),
                        );
                        return;
                      }
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
  }) => showPointRecordDialog(context, record, isNew: isNew);
}

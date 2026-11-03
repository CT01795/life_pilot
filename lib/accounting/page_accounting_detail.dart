import 'package:flutter/material.dart';
import 'package:life_pilot/utils/widgets/widgets_ledger_record_tile.dart';
import 'package:life_pilot/record_statistics/widgets_record_totals.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/record_statistics/model_record_explorer_metrics.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:intl/intl.dart';
import 'package:life_pilot/accounting/controller_accounting_detail.dart';
import 'package:life_pilot/accounting/model_accounting_detail.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/controller_speech.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/model_accounting_preview.dart';
import 'package:life_pilot/utils/service/service_speech.dart';
import 'package:life_pilot/utils/record_categories.dart';
import 'package:life_pilot/accounting/widgets_accounting_record_dialog.dart';
import 'package:life_pilot/utils/record_filter.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/utils/widgets/widgets_record_explorer.dart';
import 'package:life_pilot/utils/widgets/widgets_record_input.dart';
import 'package:life_pilot/utils/widgets/widgets_record_preview_tile.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/subscription/widgets_subscription_usage.dart';

class PageAccountingDetail extends StatelessWidget {
  final ModelAccountingAccount account;
  final ServiceAccounting service;
  final bool returnAfterSubmit;
  final VoidCallback? onRecordsChanged;
  final String? linkedEventId;
  const PageAccountingDetail({
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
        ChangeNotifierProxyProvider<ControllerAuth, ControllerAccountingDetail>(
          create: (context) => ControllerAccountingDetail(
            service: service,
            auth: context.read<ControllerAuth>(),
            accountId: account.id,
            onRecordsChanged: onRecordsChanged,
            loadAllRecords: account.category == AccountCategory.project.name,
          ),
          update: (_, auth, controller) {
            controller ??= ControllerAccountingDetail(
              service: service,
              auth: auth,
              accountId: account.id,
              onRecordsChanged: onRecordsChanged,
              loadAllRecords: account.category == AccountCategory.project.name,
            );
            controller.updateAuth(auth, notify: false);
            return controller;
          },
        ),
        Provider<ControllerSpeech>(create: (_) => ControllerSpeech()),
        Provider<ServiceSpeech>(create: (_) => ServiceSpeech()),
      ],
      child: _PageAccountingDetailView(
        account,
        returnAfterSubmit,
        linkedEventId,
      ),
    );
  }
}

class _PageAccountingDetailView extends StatefulWidget {
  final ModelAccountingAccount account;
  final bool returnAfterSubmit;
  final String? linkedEventId;
  const _PageAccountingDetailView(
    this.account,
    this.returnAfterSubmit,
    this.linkedEventId,
  );

  @override
  State<_PageAccountingDetailView> createState() =>
      _PageAccountingDetailViewState();
}

class _PageAccountingDetailViewState extends State<_PageAccountingDetailView> {
  late ServiceSpeech _speechService;
  final TextEditingController _speechTextController = TextEditingController();
  final TextEditingController _recordSearchController = TextEditingController();
  final numberFormatter = NumberFormat('#,##0.####');
  DateTime _newRecordDate = DateTime.now();
  String _recordSearchQuery = '';
  String? _selectedRecordCategory;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<ControllerAccountingDetail>();
      controller.currentCurrency = widget.account.currency;
      controller.loadToday(inputAccountId: widget.account.id);
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
    List<AccountingPreview> previews,
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
                      // 點整個 ListTile 都能編輯
                      final updated = await _showEditDetailDialog(context, p);
                      if (updated != null) {
                        setState(() {
                          previews[index] = updated;
                        });
                      }
                    },
                    title: Row(
                      children: [
                        Expanded(child: Text(p.description)),
                        Gaps.w8,
                        Text(
                          '${p.value >= 0 ? '+' : ''}${p.value} ${p.currency}',
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
    final controller = context.watch<ControllerAccountingDetail>();
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
                const SubscriptionUsageBanner(resource: 'accounting_detail'),
                _buildSummary(context, account, controller),
                _buildNewRecordDatePicker(context),
                _buildMicButton(context, controller),
                _buildRecordExplorer(
                  context,
                  account,
                  controller,
                  loadedRecords,
                  visibleRecords,
                ),
                const Divider(),
              ],
            ),
          ),
          _buildTodayList(controller, visibleRecords),
        ],
      ),
    );
  }

  List<ModelAccountingDetail> _filterRecords(
    List<ModelAccountingDetail> records,
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
    ModelAccountingAccount account,
    ControllerAccountingDetail controller,
    List<ModelAccountingDetail> loadedRecords,
    List<ModelAccountingDetail> visibleRecords,
  ) {
    final loc = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final currency = controller.currentCurrency ?? account.currency ?? '';
    final metrics = ModelRecordExplorerMetrics.from<ModelAccountingDetail>(
      visibleRecords,
      valueOf: (record) => record.value,
      include: currency.isEmpty
          ? null
          : (record) => record.currency == currency,
    );
    final net = metrics.net;
    final presentCategories = loadedRecords
        .map((record) => record.primaryCategory)
        .toSet();
    String metricValue(num value) => [
      numberFormatter.format(value),
      if (currency.isNotEmpty) currency,
    ].join(' ');

    return WidgetsRecordExplorer(
      searchController: _recordSearchController,
      searchHint: loc.recordSearchHint,
      clearTooltip: loc.clear,
      categories: [
        RecordCategoryFilterOption(value: null, label: loc.recordAllCategories),
        for (final category in RecordCategories.accounting)
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
          icon: Icons.south_west,
          label: loc.eventIncome,
          value: metricValue(metrics.positive),
          color: Colors.green,
        ),
        RecordExplorerMetric(
          icon: Icons.north_east,
          label: loc.eventExpense,
          value: metricValue(metrics.negativeMagnitude),
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
    ModelAccountingAccount account,
    ControllerAccountingDetail controller,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: WidgetsRecordTotals(
            accountId: account.id,
            accountName: account.accountName,
            kind: RecordStatisticsKind.accounting,
            currency: controller.currentCurrency ?? account.currency,
            total: controller.total ?? account.balance,
            revision: controller.todayRecords,
          ),
        ),
      ),
    );
  }

  Widget _buildTodayList(
    ControllerAccountingDetail controller,
    List<ModelAccountingDetail> visibleRecords,
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
          currency: record.currency,
          onDelete: () => _deleteRecord(controller, record.id),
          onEdit: () async {
            final updated = await _showEditDetailDialog(
              context,
              AccountingPreview(
                id: record.id,
                description: record.description,
                value: record.value,
                currency: record.currency,
                exchangeRate: null,
                date: record.localTime,
                primaryCategory: record.primaryCategory,
                secondaryCategory: record.secondaryCategory,
              ),
            );
            if (updated != null) {
              await controller.updateAccountingDetail(updated);
              //setState(() {});
            }
          },
        );
      },
    );
  }

  Future<void> _deleteRecord(
    ControllerAccountingDetail controller,
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
    try {
      await controller.deleteAccountingDetail(detailId);
    } catch (error) {
      if (!mounted) return;
      final message = subscriptionErrorMessage(loc, error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.isNotEmpty ? message : loc.unknownError),
        ),
      );
    }
  }

  Widget _buildNewRecordDatePicker(BuildContext context) {
    return WidgetsRecordDateTimePicker(
      value: _newRecordDate,
      onChanged: (value) => setState(() => _newRecordDate = value),
    );
  }

  Widget _buildMicButton(
    BuildContext context,
    ControllerAccountingDetail controller,
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
                      tooltip: loc.accountingSpeechExample,
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
                          hintText: loc.accountingSpeechHint,
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
                      final List<AccountingPreview> previews;
                      try {
                        previews = controller.parseFromSpeech(
                          _speechTextController.text,
                          latest?.currency ??
                              controller.currentCurrency ??
                              widget.account.currency,
                          controller.currentExchangeRate,
                        );
                      } on FormatException {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(loc.recordTextInvalid)),
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
    ControllerAccountingDetail controller,
  ) async {
    final latest = firstRecordOutsideCategory(
      controller.todayRecords,
      excludedCategory: RecordCategories.reserved,
      primaryCategoryOf: (record) => record.primaryCategory,
    );
    final draft = AccountingPreview(
      description: '',
      value: latest?.value ?? -1,
      currency:
          latest?.currency ??
          controller.currentCurrency ??
          widget.account.currency,
      exchangeRate: controller.currentExchangeRate,
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

  // 回傳修改後的 AccountingPreview，取消則回傳 null
  Future<AccountingPreview?> _showEditDetailDialog(
    BuildContext context,
    AccountingPreview record, {
    bool isNew = false,
  }) => showAccountingRecordDialog(
    context,
    record,
    isNew: isNew,
    defaultCurrency: widget.account.currency,
  );
}

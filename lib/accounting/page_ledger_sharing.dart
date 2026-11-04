import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/widgets/widgets_ledger_record_tile.dart';
import 'package:life_pilot/accounting/service_ledger_sharing.dart';
import 'package:life_pilot/accounting/controller_shared_ledger_overview.dart';
import 'package:life_pilot/accounting/controller_ledger_review_refresh.dart';
import 'package:life_pilot/accounting/model_accounting_preview.dart';
import 'package:life_pilot/accounting/widgets_accounting_record_dialog.dart';
import 'package:life_pilot/point_record/model_point_record_preview.dart';
import 'package:life_pilot/point_record/widgets_point_record_record_dialog.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/record_statistics/widgets_record_totals.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/record_statistics/page_record_statistics.dart';
import 'package:life_pilot/record_statistics/service_record_statistics.dart';
import 'package:life_pilot/utils/record_categories.dart';
import 'package:life_pilot/utils/widgets/widgets_load_error.dart';

Future<void> openSharedLedger(
  BuildContext context, {
  required LedgerKind kind,
  required String shareId,
  required String name,
  bool proposeOnOpen = false,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => _SharedLedgerEntriesPage(
      service: ServiceLedgerSharing(),
      kind: kind,
      shareId: shareId,
      name: name,
      proposeOnOpen: proposeOnOpen,
    ),
  ),
);

class SharedLedgerOverview extends StatefulWidget {
  const SharedLedgerOverview({required this.kind, super.key});
  final LedgerKind kind;

  @override
  State<SharedLedgerOverview> createState() => _SharedLedgerOverviewState();
}

class SharedLedgerHomePreview extends StatefulWidget {
  const SharedLedgerHomePreview({
    required this.kind,
    required this.id,
    required this.name,
    super.key,
  });
  final LedgerKind kind;
  final String id;
  final String name;

  @override
  State<SharedLedgerHomePreview> createState() =>
      _SharedLedgerHomePreviewState();
}

class _SharedLedgerHomePreviewState extends State<SharedLedgerHomePreview>
    with WidgetsBindingObserver {
  late Future<Map<String, dynamic>> _summary;
  late Future<List<Map<String, dynamic>>> _entries;
  bool? _routeCurrent;

  void _load() {
    final snapshot = ServiceLedgerSharing().homePreview(widget.id);
    _summary = snapshot.then((data) => data.totals);
    _entries = snapshot.then((data) => data.entries);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.isCurrentOf(context);
    if (current == true && _routeCurrent == false) _load();
    _routeCurrent = current;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _routeCurrent != false) {
      setState(_load);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final accounting = widget.kind == LedgerKind.accounting;
    final formatter = NumberFormat(
      accounting ? '#,##0.##' : '#,###',
      loc.localeName,
    );
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _SharedLedgerTotals(id: widget.id, kind: widget.kind, source: _summary),
        const Divider(),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _entries,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              return WidgetsLoadError(onRetry: () => setState(_load));
            }
            final rows = snapshot.data ?? [];
            return Column(
              children: [
                if (rows.isEmpty)
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(loc.noInfoAvailable),
                  ),
                for (final row in rows)
                  if (row['entry'] case final Map entry)
                    Builder(
                      builder: (context) {
                        final amount = num.tryParse(
                          entry['value']?.toString() ?? '',
                        );
                        final currency = accounting
                            ? entry['currency']?.toString() ?? ''
                            : '';
                        return ListTile(
                          dense: true,
                          title: Text(
                            entry['description']?.toString() ?? '',
                            style: theme.textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            entry['secondary_category']?.toString() ?? '',
                            style: theme.textTheme.titleMedium,
                          ),
                          trailing: Text(
                            amount == null
                                ? '—'
                                : '${formatter.format(amount)} $currency'
                                      .trim(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: amount != null && amount < 0
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SharedLedgerTotals extends StatefulWidget {
  const _SharedLedgerTotals({
    required this.id,
    required this.kind,
    this.revision = 0,
    this.overviewTotals,
    this.refreshOnRouteReturn = true,
    this.source,
    this.refreshSourceIndependently = false,
  });
  final bool refreshSourceIndependently;
  final Future<Map<String, dynamic>>? source;
  final Map<String, dynamic>? overviewTotals;
  final bool refreshOnRouteReturn;
  final int revision;
  final String id;
  final LedgerKind kind;

  @override
  State<_SharedLedgerTotals> createState() => _SharedLedgerTotalsState();
}

class _SharedLedgerTotalsState extends State<_SharedLedgerTotals>
    with WidgetsBindingObserver {
  late var _totals = _initialTotals();
  Future<Map<String, dynamic>> _initialTotals() {
    if (widget.source case final source?) return source;
    final totals = widget.overviewTotals;
    return totals == null
        ? ServiceLedgerSharing().totals(widget.id)
        : Future.value(totals);
  }

  Map<String, dynamic>? _lastTotals;
  bool? _routeCurrent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.isCurrentOf(context);
    if (widget.source == null &&
        widget.refreshOnRouteReturn &&
        current == true &&
        _routeCurrent == false) {
      _totals = ServiceLedgerSharing().totals(widget.id);
    }
    _routeCurrent = current;
  }

  @override
  void didUpdateWidget(covariant _SharedLedgerTotals oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) _lastTotals = null;
    if (oldWidget.id != widget.id ||
        oldWidget.source != widget.source ||
        !identical(oldWidget.overviewTotals, widget.overviewTotals) ||
        (widget.overviewTotals == null &&
            oldWidget.revision != widget.revision)) {
      _totals = _initialTotals();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((widget.source == null || widget.refreshSourceIndependently) &&
        state == AppLifecycleState.resumed &&
        _routeCurrent != false) {
      setState(() => _totals = ServiceLedgerSharing().totals(widget.id));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(widget.id),
      future: _totals,
      builder: (context, snapshot) {
        if (snapshot.hasData) _lastTotals = snapshot.data;
        final error = snapshot.error;
        if (error is StateError ||
            (error is PostgrestException &&
                const {
                  '42501',
                  'PGRST301',
                  'PGRST302',
                  'PGRST303',
                }.contains(error.code))) {
          _lastTotals = null;
        }
        final data = _lastTotals;
        num? number(String key) => num.tryParse(data?[key]?.toString() ?? '');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RecordTotalsDisplay(
              points: widget.kind == LedgerKind.points,
              currency: data?['currency']?.toString(),
              total: number('total'),
              month: number('month'),
              today: number('today'),
            ),
            if (snapshot.connectionState != ConnectionState.done &&
                data == null)
              const LinearProgressIndicator()
            else if (snapshot.hasError &&
                (widget.source == null || widget.refreshSourceIndependently))
              TextButton.icon(
                onPressed: () => setState(
                  () => _totals = ServiceLedgerSharing().totals(widget.id),
                ),
                icon: const Icon(Icons.refresh),
                label: Text(loc.retry),
              ),
          ],
        );
      },
    );
  }
}

class _SharedLedgerOverviewState extends State<SharedLedgerOverview> {
  int _limit = ControllerSharedLedgerOverview.pageSize;
  int _revision = 0;
  bool _loadingMore = false;
  late final _controller = ControllerSharedLedgerOverview(widget.kind);
  final _declined = <String>{};
  final _declining = <String>{};
  late Future<List<Map<String, dynamic>>> _rows = _load();

  Future<List<Map<String, dynamic>>> _load() => _controller.refresh(_limit);

  Future<void> _loadMore(List<Map<String, dynamic>> current) async {
    if (_loadingMore || _declining.isNotEmpty) return;
    final loc = AppLocalizations.of(context)!;
    setState(() => _loadingMore = true);
    try {
      final next = await _controller.next(current);
      if (!mounted) return;
      setState(() {
        _limit += ControllerSharedLedgerOverview.pageSize;
        _rows = Future.value(next);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.retry)));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _decline(String id) async {
    if (_declining.contains(id)) return;
    final loc = AppLocalizations.of(context)!;
    if (!await _confirmLedgerAction(
          context,
          loc.ledgerDeclineShareConfirm,
          details: Text(loc.ledgerDeclineShareExplanation),
        ) ||
        !mounted ||
        _declining.contains(id) ||
        _loadingMore) {
      return;
    }
    setState(() => _declining.add(id));
    try {
      await _controller.decline(id);
      if (!mounted) return;
      setState(() {
        _declined.add(id);
        _rows = _load();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.adminSubscriptionSaveFailed(error.toString())),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _declining.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _rows,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return WidgetsLoadError(
            onRetry: () => setState(() => _rows = _load()),
          );
        }
        final rows = snapshot.data
            ?.where(
              (row) =>
                  row['share_id'] != null &&
                  !_declined.contains(row['share_id']),
            )
            .toList(growable: false);
        if (rows == null || rows.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (final row in rows.take(_limit))
              _SharedLedgerAccountCard(
                key: ValueKey(row['share_id']),
                kind: widget.kind,
                id: row['share_id'] as String,
                name: row['account_name'] as String? ?? '',
                revision: _revision,
                overviewTotals: row['totals'] as Map<String, dynamic>?,
                showRefresh: identical(row, rows.first),
                onRefresh:
                    _loadingMore ||
                        snapshot.connectionState != ConnectionState.done
                    ? null
                    : () => setState(() {
                        _revision++;
                        _rows = _load();
                      }),
                onDecline: _loadingMore || _declining.contains(row['share_id'])
                    ? null
                    : () => _decline(row['share_id'] as String),
              ),
            if (rows.length > _limit || snapshot.data!.last['share_id'] == null)
              TextButton(
                onPressed:
                    _loadingMore ||
                        _declining.isNotEmpty ||
                        snapshot.connectionState != ConnectionState.done
                    ? null
                    : () => _loadMore(snapshot.data!),
                child: Text(AppLocalizations.of(context)!.clickHereToSeeMore),
              ),
          ],
        );
      },
    );
  }
}

class _SharedLedgerAccountCard extends StatelessWidget {
  const _SharedLedgerAccountCard({
    required this.kind,
    required this.id,
    required this.name,
    required this.revision,
    required this.overviewTotals,
    required this.onDecline,
    required this.showRefresh,
    required this.onRefresh,
    super.key,
  });
  final LedgerKind kind;
  final String id;
  final String name;
  final int revision;
  final Map<String, dynamic>? overviewTotals;
  final VoidCallback? onDecline;
  final bool showRefresh;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final compact = MediaQuery.sizeOf(context).width < 400;
    return Card(
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () =>
            openSharedLedger(context, kind: kind, shareId: id, name: name),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 84 : 120,
                height: compact ? 84 : 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isEmpty ? '' : name.characters.first,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              SizedBox(width: compact ? 8 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      avatar: const Icon(Icons.group_outlined),
                      label: Text(loc.ledgerSharedAccount),
                    ),
                    _SharedLedgerTotals(
                      id: id,
                      kind: kind,
                      revision: revision,
                      overviewTotals: overviewTotals,
                    ),
                    _SharedLedgerStatisticsButton(
                      id: id,
                      kind: kind,
                      name: name,
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: onDecline,
                        child: Text(loc.ledgerDeclineShare),
                      ),
                    ),
                  ],
                ),
              ),
              if (showRefresh)
                IconButton(
                  tooltip: loc.refreshList,
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                )
              else
                const Icon(Icons.chevron_right, color: Color(0xFF212121)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedLedgerStatisticsButton extends StatelessWidget {
  const _SharedLedgerStatisticsButton({
    required this.id,
    required this.kind,
    required this.name,
  });
  final String id;
  final LedgerKind kind;
  final String name;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return TextButton.icon(
      icon: const Icon(Icons.bar_chart),
      label: Text(loc.recordStatistics),
      onPressed: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PageRecordStatistics(
            accountId: id,
            accountName: name,
            kind: kind == LedgerKind.points
                ? RecordStatisticsKind.points
                : RecordStatisticsKind.accounting,
            service: ServiceRecordStatistics(sharedLedgerId: id),
          ),
        ),
      ),
    );
  }
}

class LedgerSharingButton extends StatelessWidget {
  const LedgerSharingButton({required this.kind, this.accountId, super.key});

  final LedgerKind kind;
  final String? accountId;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final label = accountId == null
        ? loc.ledgerSharedWithMe
        : loc.ledgerShareAccount;
    void open() => Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _LedgerSharingPage(kind: kind, accountId: accountId),
      ),
    );
    return accountId == null
        ? TextButton.icon(
            onPressed: open,
            icon: const Icon(Icons.group_outlined),
            label: Text(label),
          )
        : IconButton(
            onPressed: open,
            icon: const Icon(Icons.share_outlined),
            tooltip: label,
          );
  }
}

final _ledgerPendingChanges =
    ValueNotifier<({LedgerKind kind, String id, Object revision})?>(null);

class LedgerReviewButton extends StatefulWidget {
  const LedgerReviewButton({
    required this.kind,
    required this.accountId,
    this.onApproved,
    super.key,
  });

  final LedgerKind kind;
  final String accountId;
  final VoidCallback? onApproved;

  @override
  State<LedgerReviewButton> createState() => _LedgerReviewButtonState();
}

class _LedgerReviewButtonState extends State<LedgerReviewButton>
    with WidgetsBindingObserver {
  final _service = ServiceLedgerSharing();
  int _count = 0;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ledgerPendingChanges.addListener(_onPendingChanged);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant LedgerReviewButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind ||
        oldWidget.accountId != widget.accountId) {
      _count = 0;
      _refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ledgerPendingChanges.removeListener(_onPendingChanged);
    super.dispose();
  }

  void _onPendingChanged() {
    final change = _ledgerPendingChanges.value;
    if (change?.kind == widget.kind && change?.id == widget.accountId) {
      _refresh(accountOnly: true);
    }
  }

  Future<void> _refresh({bool accountOnly = false}) async {
    final request = ++_request;
    final accountId = widget.accountId;
    try {
      final counts = await _service.pendingCounts(
        widget.kind,
        accountId: accountOnly ? accountId : null,
      );
      if (!mounted || request != _request) return;
      final count = counts[accountId] ?? 0;
      if (_count != count) setState(() => _count = count);
    } catch (_) {
      // A badge failure must not disable access to the review screen.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_count <= 0) return const SizedBox.shrink();
    final loc = AppLocalizations.of(context)!;
    final count = NumberFormat.decimalPattern(loc.localeName).format(_count);
    return TextButton.icon(
      icon: const Badge(child: Icon(Icons.fact_check_outlined)),
      label: Text('${loc.ledgerPendingProposals} ($count)'),
      onPressed: () async {
        final kind = widget.kind;
        final accountId = widget.accountId;
        bool current() =>
            mounted && widget.kind == kind && widget.accountId == accountId;
        var returned = false;
        final onApproved = widget.onApproved;
        final refresh = ControllerLedgerReviewRefresh(() => onApproved?.call());
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => _LedgerReviewPage(
              service: _service,
              fetch: (offset) =>
                  _service.accountProposals(kind, accountId, offset),
              onApproved: refresh.approved,
              onReviewed: () {
                if (!current()) return;
                if (returned) {
                  // A review may finish after the user has left the route.
                  _refresh(accountOnly: true);
                  return;
                }
                ++_request;
                if (_count > 0) setState(() => _count--);
              },
            ),
          ),
        );
        returned = true;
        refresh.close();
        if (current()) await _refresh(accountOnly: true);
      },
    );
  }
}

class _LedgerSharingPage extends StatefulWidget {
  const _LedgerSharingPage({required this.kind, this.accountId});
  final LedgerKind kind;
  final String? accountId;

  @override
  State<_LedgerSharingPage> createState() => _LedgerSharingPageState();
}

class _LedgerSharingPageState extends State<_LedgerSharingPage> {
  final _service = ServiceLedgerSharing();
  final _email = TextEditingController();
  final _listKey = GlobalKey<_LedgerPagesState>();
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _mutate(
    Future<void> Function() action, {
    bool refreshList = true,
    bool pendingChanged = false,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      final id = widget.accountId;
      if (pendingChanged && id != null) {
        _ledgerPendingChanges.value = (
          kind: widget.kind,
          id: id,
          revision: Object(),
        );
      }
      if (mounted && refreshList) {
        await _listKey.currentState?.load(reset: true);
      }
    } catch (error) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.adminSubscriptionSaveFailed(error.toString())),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final id = widget.accountId;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          id == null ? loc.ledgerSharedWithMe : loc.ledgerShareAccount,
        ),
      ),
      body: Column(
        children: [
          if (id != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _email,
                enabled: !_saving,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: loc.email,
                  suffixIcon: IconButton(
                    tooltip: loc.ledgerShareAccount,
                    icon: const Icon(Icons.send_outlined),
                    onPressed: _saving
                        ? null
                        : () async {
                            final email = _email.text.trim();
                            if (!RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(email)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(loc.invalidEmail)),
                              );
                              return;
                            }
                            await _mutate(() async {
                              await _service.share(widget.kind, id, email);
                              if (mounted) _email.clear();
                            });
                          },
                  ),
                ),
              ),
            ),
          Expanded(
            child: _LedgerPages(
              key: _listKey,
              fetch: id == null
                  ? _service.received
                  : (offset) => _service.outgoing(widget.kind, id, offset),
              include: (row) => id != null || row['kind'] == widget.kind.name,
              item: (context, row) {
                final shareId = row['share_id'] as String;
                if (id != null) {
                  final email = row['recipient_email']?.toString() ?? '';
                  return ListTile(
                    title: Text(email),
                    leading: const Icon(Icons.person_outline),
                    trailing: PopupMenuButton<String>(
                      enabled: !_saving,
                      onSelected: (action) async {
                        final question = switch (action) {
                          'allow' => loc.ledgerAllowProposalsConfirm,
                          'stop' => loc.ledgerStopProposalsConfirm,
                          _ => loc.ledgerStopSharingConfirm,
                        };
                        if (!await _confirmLedgerAction(
                              context,
                              question,
                              details: Text(email),
                            ) ||
                            !mounted) {
                          return;
                        }
                        await _mutate(
                          () => action == 'revoke'
                              ? _service.revoke(shareId)
                              : _service.allowProposals(
                                  shareId,
                                  action == 'allow',
                                ),
                          refreshList: action == 'revoke',
                          pendingChanged: action != 'allow',
                        );
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'allow',
                          child: Text(loc.ledgerAllowProposals),
                        ),
                        PopupMenuItem(
                          value: 'stop',
                          child: Text(loc.ledgerStopProposals),
                        ),
                        PopupMenuItem(
                          value: 'revoke',
                          child: Text(loc.ledgerStopSharing),
                        ),
                      ],
                    ),
                  );
                }
                final name = row['account_name']?.toString() ?? '';
                return ListTile(
                  title: Text(name),
                  leading: const Icon(Icons.visibility_outlined),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => _SharedLedgerEntriesPage(
                        service: _service,
                        shareId: shareId,
                        name: name,
                        kind: widget.kind,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedLedgerEntriesPage extends StatefulWidget {
  const _SharedLedgerEntriesPage({
    required this.service,
    required this.shareId,
    required this.name,
    required this.kind,
    this.proposeOnOpen = false,
  });
  final ServiceLedgerSharing service;
  final String shareId;
  final String name;
  final LedgerKind kind;
  final bool proposeOnOpen;

  @override
  State<_SharedLedgerEntriesPage> createState() =>
      _SharedLedgerEntriesPageState();
}

class _SharedLedgerEntriesPageState extends State<_SharedLedgerEntriesPage> {
  late final _formatter = NumberFormat(
    widget.kind == LedgerKind.accounting ? '#,##0.####' : '#,###',
  );
  late Future<bool> _capability;
  late Future<Map<String, dynamic>> _summary;
  Future<List<Map<String, dynamic>>>? _firstEntries;
  final _entriesKey = GlobalKey<_LedgerPagesState>();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    if (widget.proposeOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          if (await _capability && mounted) await _propose('insert');
        } catch (_) {
          // Keep the details readable when the proposal permission lookup fails.
        }
      });
    }
  }

  Future<bool> _loadCapability() => widget.service.canPropose(widget.shareId);

  void _loadFirstPage() {
    final reads = widget.service.detailFirstPage(widget.shareId);
    _capability = reads.canPropose;
    _summary = reads.totals;
    _firstEntries = reads.entries;
  }

  Future<List<Map<String, dynamic>>> _loadEntries(int offset) {
    final first = _firstEntries;
    if (offset == 0 && first != null) {
      _firstEntries = null;
      return first;
    }
    return widget.service.entries(widget.shareId, offset);
  }

  Future<Map<String, Object?>?> _editProposal(bool isNew, Map? entry) async {
    final date = DateTime.tryParse(entry?['date']?.toString() ?? '')?.toLocal();
    final description = entry?['description']?.toString() ?? '';
    final primary =
        entry?['primary_category']?.toString() ??
        RecordCategories.uncategorized;
    final secondary = entry?['secondary_category']?.toString();
    final value = entry?['value']?.toString() ?? '';
    if (widget.kind == LedgerKind.accounting) {
      final record = await showAccountingRecordDialog(
        context,
        AccountingPreview(
          description: description,
          value: num.tryParse(value) ?? 0,
          currency: entry?['currency']?.toString(),
          exchangeRate: null,
          date: date,
          primaryCategory: primary,
          secondaryCategory: secondary,
        ),
        isNew: isNew,
        proposal: true,
      );
      if (record == null) return null;
      return {
        'description': record.description,
        'value': record.value,
        'date': record.date?.toUtc().toIso8601String(),
        'primary_category': record.primaryCategory,
        'group': record.secondaryCategory,
        'currency': record.currency,
        if (isNew) 'type': 'balance',
      };
    }
    final record = await showPointRecordDialog(
      context,
      PointRecordPreview(
        description: description,
        value: int.tryParse(value) ?? 0,
        date: date,
        primaryCategory: primary,
        secondaryCategory: secondary,
      ),
      isNew: isNew,
      proposal: true,
    );
    if (record == null) return null;
    return {
      'description': record.description,
      'value': record.value,
      'date': record.date?.toUtc().toIso8601String(),
      'primary_category': record.primaryCategory,
      'group': record.secondaryCategory,
      if (isNew) 'type': 'points',
    };
  }

  Future<void> _propose(String operation, [Map? entry]) async {
    if (_sending) return;
    final loc = AppLocalizations.of(context)!;
    var permissionDenied = false;
    setState(() => _sending = true);
    try {
      Map<String, Object?>? changes;
      if (operation == 'delete') {
        if (await _confirmLedgerAction(
          context,
          loc.ledgerSubmitProposal,
          details: Text('${loc.delete}: ${entry?['description'] ?? ''}'),
        )) {
          changes = {};
        }
      } else {
        changes = await _editProposal(operation == 'insert', entry);
      }
      if (!mounted || changes == null) return;
      await widget.service.submitProposal(
        widget.shareId,
        operation,
        entry?['id']?.toString(),
        changes,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.ledgerProposalSent)));
      }
    } catch (error) {
      permissionDenied = error is PostgrestException && error.code == '42501';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.adminSubscriptionSaveFailed(error.toString())),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          // The server already validates permission on submission. A
          // successful proposal or a dismissed form does not change it.
          if (permissionDenied) _capability = _loadCapability();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return FutureBuilder<bool>(
      future: _capability,
      builder: (context, snapshot) {
        final canPropose =
            snapshot.connectionState == ConnectionState.done &&
            snapshot.data == true;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              '${widget.name} · ${loc.ledgerSharedAccount}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                tooltip: loc.refreshList,
                onPressed: _sending
                    ? null
                    : () {
                        setState(_loadFirstPage);
                        _entriesKey.currentState?.load(reset: true);
                      },
                icon: const Icon(Icons.refresh),
              ),
              if (canPropose)
                IconButton(
                  tooltip: loc.ledgerSubmitProposal,
                  onPressed: _sending ? null : () => _propose('insert'),
                  icon: const Icon(Icons.add),
                ),
            ],
          ),
          body: _LedgerPages(
            key: _entriesKey,
            header: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SharedLedgerTotals(
                    source: _summary,
                    refreshSourceIndependently: true,
                    id: widget.shareId,
                    kind: widget.kind,
                    // Returning from a proposal dialog does not change totals.
                    refreshOnRouteReturn: false,
                  ),
                  _SharedLedgerStatisticsButton(
                    id: widget.shareId,
                    kind: widget.kind,
                    name: widget.name,
                  ),
                ],
              ),
            ),
            fetch: _loadEntries,
            item: (context, row) {
              final entry = row['entry'] as Map;
              final date = DateTime.tryParse(
                entry['date']?.toString() ?? '',
              )?.toLocal();
              final editable = canPropose && !_sending;
              return WidgetsLedgerRecordTile(
                key: ValueKey(entry['id']),
                description: entry['description']?.toString() ?? '',
                displayTime: date == null
                    ? ''
                    : DateTimeFormatter.formatTime(date),
                primaryCategory:
                    entry['primary_category']?.toString() ??
                    RecordCategories.uncategorized,
                value: num.tryParse(entry['value']?.toString() ?? ''),
                formatter: _formatter,
                currency: widget.kind == LedgerKind.accounting
                    ? entry['currency']?.toString()
                    : null,
                onEdit: editable ? () => _propose('update', entry) : null,
                onDelete: editable ? () => _propose('delete', entry) : null,
              );
            },
          ),
        );
      },
    );
  }
}

Future<bool> _confirmLedgerAction(
  BuildContext context,
  String label, {
  Widget? details,
}) async {
  final loc = AppLocalizations.of(context)!;
  return await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(label),
          content: details,
          scrollable: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(loc.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(loc.confirm),
            ),
          ],
        ),
      ) ==
      true;
}

class _LedgerReviewPage extends StatefulWidget {
  const _LedgerReviewPage({
    required this.service,
    required this.fetch,
    required this.onReviewed,
    this.onApproved,
  });
  final ServiceLedgerSharing service;
  final Future<List<Map<String, dynamic>>> Function(int) fetch;
  final VoidCallback? onApproved;
  final VoidCallback onReviewed;

  @override
  State<_LedgerReviewPage> createState() => _LedgerReviewPageState();
}

class _LedgerReviewPageState extends State<_LedgerReviewPage> {
  final _listKey = GlobalKey<_LedgerPagesState>();
  bool _busy = false;

  Future<void> _review(String id, bool approve, Widget details) async {
    if (_busy) return;
    final loc = AppLocalizations.of(context)!;
    final label = approve
        ? loc.ledgerApproveProposal
        : loc.ledgerRejectProposal;
    setState(() => _busy = true);
    try {
      if (!await _confirmLedgerAction(context, label, details: details) ||
          !mounted) {
        return;
      }
      await widget.service.review(id, approve);
      if (approve) widget.onApproved?.call();
      widget.onReviewed();
      if (mounted) _listKey.currentState?.removeReviewedProposal(id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.adminSubscriptionSaveFailed(error.toString())),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.ledgerPendingProposals)),
      body: _LedgerPages(
        key: _listKey,
        fetch: widget.fetch,
        item: (context, row) {
          final operation = switch (row['operation']) {
            'insert' => loc.add,
            'delete' => loc.delete,
            _ => loc.edit,
          };
          final changes = row['changes'] as Map? ?? const {};
          final amount = changes['value'];
          final category = changes['primary_category'];
          String? dateLabel(Object? value) {
            final date = DateTime.tryParse(value?.toString() ?? '');
            return date == null
                ? null
                : DateFormat.yMMMd(
                    loc.localeName,
                  ).add_jm().format(date.toLocal());
          }

          final details = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (row['recipient_email'] case final String email)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${loc.email}：$email'),
                ),
              for (final (label, value) in [
                (loc.description, changes['description']),
                (
                  loc.amountLabel,
                  amount is num
                      ? NumberFormat.decimalPattern(
                          loc.localeName,
                        ).format(amount)
                      : null,
                ),
                (loc.currencyLabel, changes['currency']),
                (loc.recordDate, dateLabel(changes['date'])),
                (
                  loc.recordPrimaryCategory,
                  category is String
                      ? RecordCategories.label(loc, category)
                      : null,
                ),
                (loc.recordSecondaryCategory, changes['group']),
              ])
                if (value != null && value.toString().trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('$label：$value'),
                  ),
              if (changes.isEmpty)
                if (row['entry_id'] case final String id) SelectableText(id),
            ],
          );
          final proposalId = row['id'] as String;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    operation,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (dateLabel(row['created_at']) case final String submitted)
                    Text(
                      submitted,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 12),
                  details,
                  const Divider(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        label: Text(loc.ledgerRejectProposal),
                        onPressed: _busy
                            ? null
                            : () => _review(proposalId, false, details),
                        icon: const Icon(Icons.close),
                      ),
                      FilledButton.icon(
                        label: Text(loc.ledgerApproveProposal),
                        onPressed: _busy
                            ? null
                            : () => _review(proposalId, true, details),
                        icon: const Icon(Icons.check),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LedgerPages extends StatefulWidget {
  const _LedgerPages({
    required this.fetch,
    required this.item,
    this.include,
    this.header,
    super.key,
  });
  final Future<List<Map<String, dynamic>>> Function(int) fetch;
  final Widget Function(BuildContext, Map<String, dynamic>) item;
  final bool Function(Map<String, dynamic>)? include;
  final Widget? header;

  @override
  State<_LedgerPages> createState() => _LedgerPagesState();
}

class _LedgerPagesState extends State<_LedgerPages> {
  final _rows = <Map<String, dynamic>>[];
  int _offset = 0;
  bool _more = true;
  bool _busy = false;
  bool _failed = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  // Review pages are unfiltered: a processed proposal also leaves the
  // server's pending result, so the next offset must move back by one.
  void removeReviewedProposal(String id) {
    final index = _rows.indexWhere((row) => row['id'] == id);
    if (index < 0) return;
    ++_request;
    setState(() {
      _rows.removeAt(index);
      _offset--;
      _busy = false;
    });
  }

  Future<void> load({bool reset = false}) async {
    if (_busy && !reset) return;
    final request = ++_request;
    setState(() {
      _busy = true;
      _failed = false;
      if (reset) {
        _rows.clear();
        _offset = 0;
        _more = true;
      }
    });
    try {
      final page = await widget.fetch(_offset);
      if (!mounted || request != _request) return;
      setState(() {
        _rows.addAll(page.where((row) => widget.include?.call(row) ?? true));
        _offset += page.length;
        _more = page.length == ServiceLedgerSharing.pageSize;
        _busy = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _failed = true;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final header = widget.header;
    return ListView.builder(
      itemCount: _rows.length + 1 + (header == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (header != null && index == 0) return header;
        final i = index - (header == null ? 0 : 1);
        if (i < _rows.length) return widget.item(context, _rows[i]);
        if (_busy) return const LinearProgressIndicator();
        if (_failed) return WidgetsLoadError(onRetry: load);
        if (_more) {
          return TextButton(
            onPressed: load,
            child: Text(loc.clickHereToSeeMore),
          );
        }
        if (_rows.isEmpty) return Center(child: Text(loc.noData));
        return const SizedBox.shrink();
      },
    );
  }
}

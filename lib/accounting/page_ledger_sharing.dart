import 'package:flutter/material.dart';
import 'package:life_pilot/accounting/service_ledger_sharing.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/widgets/widgets_load_error.dart';

final _homeLinkRevision = ValueNotifier<int>(0);

Future<void> openSharedLedger(
  BuildContext context, {
  required LedgerKind kind,
  required String shareId,
  required String name,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => _SharedLedgerEntriesPage(
      service: ServiceLedgerSharing(),
      kind: kind,
      shareId: shareId,
      name: name,
    ),
  ),
);

class SharedLedgerOverview extends StatefulWidget {
  const SharedLedgerOverview({required this.kind, super.key});
  final LedgerKind kind;

  @override
  State<SharedLedgerOverview> createState() => _SharedLedgerOverviewState();
}

class _SharedLedgerOverviewState extends State<SharedLedgerOverview> {
  late Future<List<Map<String, dynamic>>> _rows = _load();

  Future<List<Map<String, dynamic>>> _load() =>
      ServiceLedgerSharing().receivedFor(widget.kind, maxResults: 6);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _rows,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return WidgetsLoadError(
            onRetry: () => setState(() => _rows = _load()),
          );
        }
        final rows = snapshot.data;
        if (rows == null || rows.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 84,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final name = row['account_name'] as String? ?? '';
              return SizedBox(
                width: 220,
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.group_outlined),
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(loc.ledgerSharedAccount),
                    onTap: () => openSharedLedger(
                      context,
                      kind: widget.kind,
                      shareId: row['share_id'] as String,
                      name: name,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class LedgerHomeLinksCard extends StatefulWidget {
  const LedgerHomeLinksCard({
    required this.showAccounting,
    required this.showPoints,
    super.key,
  });
  final bool showAccounting;
  final bool showPoints;

  @override
  State<LedgerHomeLinksCard> createState() => _LedgerHomeLinksCardState();
}

class _LedgerHomeLinksCardState extends State<LedgerHomeLinksCard> {
  final _service = ServiceLedgerSharing();
  Future<List<Map<String, dynamic>>>? _links;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _homeLinkRevision.addListener(_refresh);
  }

  @override
  void dispose() {
    _homeLinkRevision.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _links = _expanded ? _service.homeLinks() : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.link),
        title: Text(loc.ledgerHomeLinks),
        onExpansionChanged: (open) {
          _expanded = open;
          _refresh();
        },
        children: [
          if (_expanded)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _links,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return WidgetsLoadError(onRetry: _refresh);
                }
                final links = (snapshot.data ?? []).where(
                  (row) => row['kind'] == LedgerKind.accounting.name
                      ? widget.showAccounting
                      : row['kind'] == LedgerKind.points.name &&
                            widget.showPoints,
                );
                if (links.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(loc.noData),
                  );
                }
                return Column(
                  children: [
                    for (final link in links)
                      ListTile(
                        leading: Icon(
                          link['kind'] == LedgerKind.accounting.name
                              ? Icons.account_balance_wallet_outlined
                              : Icons.stars_outlined,
                        ),
                        title: Text(link['account_name']?.toString() ?? ''),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => _SharedLedgerEntriesPage(
                              service: _service,
                              shareId: link['share_id'] as String,
                              name: link['account_name']?.toString() ?? '',
                              kind: LedgerKind.values.byName(
                                link['kind'] as String,
                              ),
                              readOnly: true,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
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

  Future<void> _mutate(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      if (mounted) {
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
                  return ListTile(
                    title: Text(row['recipient_email']?.toString() ?? ''),
                    trailing: PopupMenuButton<String>(
                      enabled: !_saving,
                      onSelected: (action) async {
                        if (action == 'review') {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => _LedgerReviewPage(
                                service: _service,
                                shareId: shareId,
                              ),
                            ),
                          );
                        } else if (action == 'allow') {
                          await _mutate(
                            () => _service.allowProposals(shareId, true),
                          );
                        } else {
                          final label = action == 'stop'
                              ? loc.ledgerStopProposals
                              : loc.delete;
                          if (!await _confirmLedgerAction(context, label) ||
                              !mounted) {
                            return;
                          }
                          await _mutate(
                            () => action == 'stop'
                                ? _service.allowProposals(shareId, false)
                                : _service.revoke(shareId),
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'review',
                          child: Text(loc.ledgerPendingProposals),
                        ),
                        PopupMenuItem(
                          value: 'allow',
                          child: Text(loc.ledgerAllowProposals),
                        ),
                        PopupMenuItem(
                          value: 'stop',
                          child: Text(loc.ledgerStopProposals),
                        ),
                        PopupMenuItem(value: 'revoke', child: Text(loc.delete)),
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
    this.readOnly = false,
  });
  final ServiceLedgerSharing service;
  final String shareId;
  final String name;
  final LedgerKind kind;
  final bool readOnly;

  @override
  State<_SharedLedgerEntriesPage> createState() =>
      _SharedLedgerEntriesPageState();
}

class _SharedLedgerEntriesPageState extends State<_SharedLedgerEntriesPage> {
  late Future<bool> _capability = _loadCapability();
  final _entriesKey = GlobalKey<_LedgerPagesState>();
  bool _sending = false;

  Future<bool> _loadCapability() => widget.readOnly
      ? Future.value(false)
      : widget.service.canPropose(widget.shareId);

  Future<void> _setHomeLink(bool linked) async {
    if (_sending) return;
    final loc = AppLocalizations.of(context)!;
    setState(() => _sending = true);
    try {
      await widget.service.setHomeLink(widget.shareId, linked);
      _homeLinkRevision.value++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(linked ? loc.ledgerLinkHome : loc.ledgerUnlinkHome),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.adminSubscriptionSaveFailed(error.toString())),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _propose(String operation, [Map? entry]) async {
    if (_sending) return;
    final loc = AppLocalizations.of(context)!;
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
        changes = await showDialog<Map<String, Object?>>(
          context: context,
          builder: (_) => _LedgerProposalForm(kind: widget.kind, entry: entry),
        );
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
          _capability = _loadCapability();
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
            title: Text(widget.name),
            actions: [
              IconButton(
                tooltip: loc.refreshList,
                onPressed: _sending
                    ? null
                    : () {
                        setState(() => _capability = _loadCapability());
                        _entriesKey.currentState?.load(reset: true);
                      },
                icon: const Icon(Icons.refresh),
              ),
              PopupMenuButton<bool>(
                enabled: !_sending,
                icon: const Icon(Icons.link),
                tooltip: loc.ledgerHomeLinks,
                onSelected: _setHomeLink,
                itemBuilder: (_) => [
                  if (!widget.readOnly)
                    PopupMenuItem(value: true, child: Text(loc.ledgerLinkHome)),
                  PopupMenuItem(
                    value: false,
                    child: Text(loc.ledgerUnlinkHome),
                  ),
                ],
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
            fetch: (offset) => widget.service.entries(widget.shareId, offset),
            item: (context, row) {
              final entry = row['entry'] as Map;
              final amount = [
                entry['value'],
                entry['currency'],
              ].whereType<Object>().join(' ');
              final date = DateTime.tryParse(
                entry['date']?.toString() ?? '',
              )?.toLocal();
              final dateText = date == null
                  ? ''
                  : MaterialLocalizations.of(context).formatMediumDate(date);
              return ListTile(
                title: Text(entry['description']?.toString() ?? ''),
                subtitle: Text(
                  [
                    dateText,
                    amount,
                  ].where((value) => value.isNotEmpty).join(' · '),
                ),
                trailing: canPropose
                    ? PopupMenuButton<String>(
                        enabled: !_sending,
                        onSelected: (operation) => _propose(operation, entry),
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'update', child: Text(loc.edit)),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(loc.delete),
                          ),
                        ],
                      )
                    : null,
              );
            },
          ),
        );
      },
    );
  }
}

class _LedgerProposalForm extends StatefulWidget {
  const _LedgerProposalForm({required this.kind, this.entry});
  final LedgerKind kind;
  final Map? entry;

  @override
  State<_LedgerProposalForm> createState() => _LedgerProposalFormState();
}

class _LedgerProposalFormState extends State<_LedgerProposalForm> {
  final _form = GlobalKey<FormState>();
  late final _description = TextEditingController(
    text: widget.entry?['description']?.toString(),
  );
  late final _amount = TextEditingController(
    text: widget.entry?['value']?.toString(),
  );
  late final _currency = TextEditingController(
    text: widget.entry?['currency']?.toString(),
  );

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _currency.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final accounting = widget.kind == LedgerKind.accounting;
    num? parseAmount() {
      if (accounting) return num.tryParse(_amount.text.trim());
      final value = int.tryParse(_amount.text.trim());
      return value != null && value >= -2147483648 && value <= 2147483647
          ? value
          : null;
    }

    return AlertDialog(
      title: Text(loc.ledgerSubmitProposal),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _description,
              maxLength: 500,
              decoration: InputDecoration(labelText: loc.description),
              validator: (value) =>
                  value?.trim().isNotEmpty == true ? null : loc.requiredField,
            ),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.numberWithOptions(
                signed: true,
                decimal: accounting,
              ),
              decoration: InputDecoration(labelText: loc.amountLabel),
              validator: (_) => parseAmount()?.isFinite == true
                  ? null
                  : loc.recordInputInvalid,
            ),
            if (accounting)
              TextFormField(
                controller: _currency,
                maxLength: 3,
                decoration: InputDecoration(labelText: loc.currencyLabel),
                validator: (value) =>
                    RegExp(r'^[A-Za-z]{3}$').hasMatch(value?.trim() ?? '')
                    ? null
                    : loc.recordInputInvalid,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(context, <String, Object?>{
              'description': _description.text.trim(),
              'value': parseAmount(),
              if (accounting) 'currency': _currency.text.trim().toUpperCase(),
              if (widget.entry == null)
                'type': accounting ? 'balance' : 'points',
            });
          },
          child: Text(loc.ledgerSubmitProposal),
        ),
      ],
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
  const _LedgerReviewPage({required this.service, required this.shareId});
  final ServiceLedgerSharing service;
  final String shareId;

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
      if (mounted) await _listKey.currentState?.load(reset: true);
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
        fetch: (offset) => widget.service.proposals(widget.shareId, offset),
        item: (context, row) {
          final operation = switch (row['operation']) {
            'insert' => loc.manualEntry,
            'delete' => loc.delete,
            _ => loc.edit,
          };
          final changes = row['changes'] as Map;
          final details = Text(
            [
              if (row['entry_id'] case final String id) id,
              for (final entry in changes.entries)
                '${entry.key}: ${entry.value}',
            ].join('\n'),
          );
          final proposalId = row['id'] as String;
          return ListTile(
            title: Text(operation),
            subtitle: details,
            trailing: Wrap(
              children: [
                IconButton(
                  tooltip: loc.ledgerRejectProposal,
                  onPressed: _busy
                      ? null
                      : () => _review(proposalId, false, details),
                  icon: const Icon(Icons.close),
                ),
                IconButton(
                  tooltip: loc.ledgerApproveProposal,
                  onPressed: _busy
                      ? null
                      : () => _review(proposalId, true, details),
                  icon: const Icon(Icons.check),
                ),
              ],
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
    super.key,
  });
  final Future<List<Map<String, dynamic>>> Function(int) fetch;
  final Widget Function(BuildContext, Map<String, dynamic>) item;
  final bool Function(Map<String, dynamic>)? include;

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
    return ListView.builder(
      itemCount: _rows.length + 1,
      itemBuilder: (context, i) {
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

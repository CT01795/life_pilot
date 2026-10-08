import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/service_subscription.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/widgets/widgets_adaptive_button.dart';

class AdminPricingVersionEditor extends StatefulWidget {
  const AdminPricingVersionEditor({this.onSaved, super.key});

  final VoidCallback? onSaved;

  @override
  State<AdminPricingVersionEditor> createState() =>
      _AdminPricingVersionEditorState();
}

class _AdminPricingVersionEditorState extends State<AdminPricingVersionEditor> {
  final _name = TextEditingController();
  final _values = <String, TextEditingController>{
    'price': TextEditingController(),
    'calendar': TextEditingController(),
    'accounting': TextEditingController(),
    'point': TextEditingController(),
    'memory': TextEditingController(),
    'game': TextEditingController(),
    'share': TextEditingController(),
    'event': TextEditingController(),
    'attraction': TextEditingController(),
    'image': TextEditingController(),
    'answerDays': TextEditingController(),
  };
  DateTime _effectiveAt = DateTime.now();
  String _storagePlan = 'cloud';
  bool _saving = false;
  late Future<List<SubscriptionPricingVersion>> _versions;
  String? _editingVersionId;
  String? _editingVersionName;

  @override
  void initState() {
    super.initState();
    _versions = ServiceSubscription().fetchPricingVersions();
  }

  @override
  void dispose() {
    _name.dispose();
    for (final controller in _values.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _number(String key) => int.tryParse(_values[key]!.text.trim());

  void _changeStoragePlan(String value) {
    setState(() {
      _storagePlan = value;
      for (final entry in _values.entries) {
        if (entry.key == 'price') continue;
        entry.value.text = value == 'local' ? '0' : '';
      }
    });
  }

  Future<void> _save() async {
    final loc = AppLocalizations.of(context)!;
    final values = {for (final key in _values.keys) key: _number(key)};
    if (_name.text.trim().isEmpty ||
        values.values.any((value) => value == null)) {
      _message(loc.adminPricingRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      final createsNewVersion =
          _editingVersionId == null ||
          _name.text.trim().toLowerCase() !=
              _editingVersionName?.trim().toLowerCase();
      final quotas = values.map((key, value) => MapEntry(key, value!));
      final service = ServiceSubscription();
      if (createsNewVersion) {
        await service.createPricingVersionAsAdmin(
          name: _name.text,
          storagePlan: _storagePlan,
          effectiveAt: _effectiveAt,
          quarterlyPrice: values['price']!,
          quotas: quotas,
        );
      } else {
        await service.updatePricingVersionAsAdmin(
          pricingVersionId: _editingVersionId!,
          name: _name.text,
          storagePlan: _storagePlan,
          effectiveAt: _effectiveAt,
          quarterlyPrice: values['price']!,
          quotas: quotas,
        );
      }
      if (!mounted) return;
      _message(
        createsNewVersion ? loc.adminPricingCreated : loc.adminPricingUpdated,
      );
      _resetForm();
      setState(() {
        _versions = service.fetchPricingVersions();
      });
      widget.onSaved?.call();
    } catch (error) {
      if (mounted) _message(loc.adminPricingCreateFailed(error.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _editVersion(SubscriptionPricingVersion version) {
    setState(() {
      _editingVersionId = version.id;
      _editingVersionName = version.name;
      _name.text = version.name;
      _storagePlan = version.storagePlan;
      _effectiveAt = version.effectiveAt.toLocal();
      _values['price']!.text = '${version.quarterlyPriceTwd}';
      _values['calendar']!.text = '${version.quotas['calendar_events'] ?? 0}';
      _values['event']!.text = '${version.quotas['recommended_events'] ?? 0}';
      _values['attraction']!.text =
          '${version.quotas['recommended_attractions'] ?? 0}';
      _values['accounting']!.text =
          '${version.quotas['accounting_detail'] ?? 0}';
      _values['point']!.text = '${version.quotas['point_record_detail'] ?? 0}';
      _values['memory']!.text = '${version.quotas['memory_trace'] ?? 0}';
      _values['game']!.text = '${version.quotas['game_questions'] ?? 0}';
      _values['share']!.text = '${version.quotas['calendar_shares'] ?? 0}';
      _values['image']!.text =
          '${(version.quotas['image_bytes'] ?? 0) ~/ (1024 * 1024)}';
      _values['answerDays']!.text =
          '${version.quotas['answer_history_days'] ?? 0}';
    });
  }

  void _resetForm() {
    _editingVersionId = null;
    _editingVersionName = null;
    _name.clear();
    _effectiveAt = DateTime.now();
    _storagePlan = 'cloud';
    for (final controller in _values.values) {
      controller.clear();
    }
  }

  Future<void> _deleteVersion(SubscriptionPricingVersion version) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.adminPricingDeleteTitle),
        content: Text(loc.adminPricingDeleteConfirmation(version.name)),
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
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ServiceSubscription().deletePricingVersionAsAdmin(
        versionId: version.id,
      );
      if (!mounted) return;
      if (_editingVersionId == version.id) _resetForm();
      _message(loc.adminPricingDeleted);
      setState(() {
        _versions = ServiceSubscription().fetchPricingVersions();
      });
      widget.onSaved?.call();
    } catch (error) {
      if (mounted) {
        _message(
          error.toString().contains('pricing_version_in_use')
              ? loc.adminPricingDeleteInUse
              : loc.adminPricingCreateFailed(error.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final labels = {
      'price': loc.adminPricingQuarterlyPrice,
      'calendar': loc.adminPricingCalendarQuota,
      'event': loc.recommendEvent,
      'attraction': loc.recommendPlaces,
      'accounting': loc.adminPricingAccountingQuota,
      'point': loc.adminPricingPointQuota,
      'memory': loc.adminPricingMemoryQuota,
      'game': loc.adminPricingGameQuota,
      'share': loc.adminPricingShareQuota,
      'image': loc.adminPricingImageQuota,
      'answerDays': loc.adminPricingAnswerDays,
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.price_change_outlined)),
        title: Text(loc.adminPricingTitle),
        subtitle: Text(loc.adminPricingSubtitle),
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              loc.adminUserExistingPlans,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Gaps.h8,
          FutureBuilder<List<SubscriptionPricingVersion>>(
            future: _versions,
            builder: (context, snapshot) {
              final versions =
                  snapshot.data ?? const <SubscriptionPricingVersion>[];
              return Column(
                children: versions
                    .map(
                      (version) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.sell_outlined),
                        title: Text(
                          version.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${version.storagePlan == 'local' ? loc.dataStorageLocal : loc.dataStorageCloud} · ${loc.vendorQuarterlyPrice(version.quarterlyPriceTwd)}',
                        ),
                        trailing: PopupMenuButton<String>(
                          enabled: !_saving,
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).showMenuTooltip,
                          onSelected: (action) {
                            if (action == 'edit') _editVersion(version);
                            if (action == 'delete') _deleteVersion(version);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Text(loc.edit)),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(loc.delete),
                            ),
                          ],
                        ),
                        onTap: _saving ? null : () => _editVersion(version),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
          const Divider(height: 28),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: loc.adminPricingVersionName,
              hintText: loc.adminPricingVersionHint,
              prefixIcon: const Icon(Icons.label_outline),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(loc.adminPricingEffectiveDate),
            subtitle: Text(
              MaterialLocalizations.of(context).formatMediumDate(_effectiveAt),
            ),
            onTap: _pickEffectiveDate,
          ),
          DropdownButtonFormField<String>(
            key: ValueKey(_storagePlan),
            initialValue: _storagePlan,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: loc.adminSubscriptionStoragePlan,
              prefixIcon: const Icon(Icons.storage_outlined),
            ),
            items: [
              DropdownMenuItem(
                value: 'cloud',
                child: Text(loc.dataStorageCloud),
              ),
              DropdownMenuItem(
                value: 'local',
                child: Text(loc.dataStorageLocal),
              ),
            ],
            onChanged: _saving
                ? null
                : (value) => _changeStoragePlan(value ?? 'cloud'),
          ),
          if (_storagePlan == 'local') ...[
            Gaps.h8,
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                loc.adminPricingLocalZeroUnlimited,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          Gaps.h12,
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720
                  ? 3
                  : constraints.maxWidth >= 440
                  ? 2
                  : 1;
              return GridView.builder(
                itemCount: _values.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 68,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final entry = _values.entries.elementAt(index);
                  return TextField(
                    controller: entry.value,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: labels[entry.key]),
                  );
                },
              );
            },
          ),
          Gaps.h16,
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: Icon(
                  _editingVersionId == null
                      ? Icons.add_chart_outlined
                      : Icons.save_outlined,
                ),
                label: AdaptiveButtonLabel(
                  _editingVersionId == null
                      ? loc.adminPricingCreate
                      : loc.adminPricingUpdate,
                ),
              ),
              if (_editingVersionId != null)
                OutlinedButton(
                  onPressed: _saving ? null : () => setState(_resetForm),
                  child: AdaptiveButtonLabel(loc.cancel),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickEffectiveDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _effectiveAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date != null) setState(() => _effectiveAt = date);
  }
}

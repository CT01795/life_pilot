import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/service_subscription.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/utils/widgets/widgets_adaptive_button.dart';

class AdminQuotaFreePeriod extends StatefulWidget {
  const AdminQuotaFreePeriod({super.key});

  @override
  State<AdminQuotaFreePeriod> createState() => _AdminQuotaFreePeriodState();
}

class _AdminQuotaFreePeriodState extends State<AdminQuotaFreePeriod> {
  final _service = ServiceSubscription();
  final _nameController = TextEditingController();
  List<QuotaFreePeriod> _periods = const [];
  String? _editingId;
  DateTime _startsAt = DateTime.now();
  DateTime _endsAt = DateTime.now().add(const Duration(days: 30));
  bool _enabled = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _editingId = null;
    _nameController.clear();
    _startsAt = DateTime.now();
    _endsAt = DateTime.now().add(const Duration(days: 30));
    _enabled = true;
  }

  Future<void> _load() async {
    try {
      final periods = await _service.fetchQuotaFreePeriods();
      if (!mounted) return;
      setState(() {
        _periods = periods;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _edit(QuotaFreePeriod period) {
    setState(() {
      _editingId = period.id;
      _nameController.text = period.name;
      _startsAt = period.startsAt;
      _endsAt = period.endsAt;
      _enabled = period.enabled;
    });
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    final loc = AppLocalizations.of(context)!;
    if (!_endsAt.isAfter(_startsAt)) {
      AppNavigator.showSnackBar(loc.quotaFreePeriodInvalidRange);
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.saveQuotaFreePeriodAsAdmin(
        id: _editingId,
        name: _nameController.text,
        startsAt: _startsAt,
        endsAt: _endsAt,
        enabled: _enabled,
      );
      if (!mounted) return;
      _resetForm();
      await _load();
      if (!mounted) return;
      AppNavigator.showSnackBar(loc.quotaFreePeriodSaved);
    } catch (_) {
      if (!mounted) return;
      AppNavigator.showSnackBar(loc.quotaFreePeriodSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(QuotaFreePeriod period) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.quotaFreePeriodClear),
        content: Text(loc.quotaFreePeriodClearConfirm),
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
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await _service.deleteQuotaFreePeriodAsAdmin(period.id);
      if (!mounted) return;
      if (_editingId == period.id) _resetForm();
      await _load();
      if (!mounted) return;
      AppNavigator.showSnackBar(loc.quotaFreePeriodCleared);
    } catch (_) {
      if (!mounted) return;
      AppNavigator.showSnackBar(loc.quotaFreePeriodSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _statusLabel(AppLocalizations loc, QuotaFreePeriod period) {
    if (!period.enabled) return loc.quotaFreePeriodDisabled;
    if (period.isActive) return loc.quotaFreePeriodActive;
    if (period.startsAt.isAfter(DateTime.now())) {
      return loc.quotaFreePeriodScheduled;
    }
    return loc.quotaFreePeriodEnded;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final formatter = DateFormat.yMd(loc.localeName).add_Hm();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.celebration_outlined),
        title: Text(loc.quotaFreePeriodTitle),
        subtitle: Text(loc.quotaFreePeriodDescription),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else ...[
            if (_periods.isEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_busy_outlined),
                title: Text(loc.quotaFreePeriodEmpty),
              )
            else
              for (final period in _periods)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    period.isActive
                        ? Icons.play_circle_fill_rounded
                        : Icons.event_outlined,
                    color: period.isActive
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(
                    period.name.trim().isEmpty
                        ? loc.quotaFreePeriodUnnamed
                        : period.name,
                  ),
                  subtitle: Text(
                    '${formatter.format(period.startsAt)} – '
                    '${formatter.format(period.endsAt)}\n'
                    '${_statusLabel(loc, period)}',
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 2,
                    children: [
                      IconButton(
                        tooltip: loc.edit,
                        onPressed: _saving ? null : () => _edit(period),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: loc.delete,
                        onPressed: _saving ? null : () => _delete(period),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _editingId == null
                    ? loc.quotaFreePeriodNew
                    : loc.quotaFreePeriodEdit,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: loc.quotaFreePeriodName,
                prefixIcon: const Icon(Icons.campaign_outlined),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final start = _DateTimeButton(
                  label: loc.quotaFreePeriodStart,
                  value: formatter.format(_startsAt),
                  onPressed: () async {
                    final value = await _pickDateTime(_startsAt);
                    if (value != null && mounted) {
                      setState(() => _startsAt = value);
                    }
                  },
                );
                final end = _DateTimeButton(
                  label: loc.quotaFreePeriodEnd,
                  value: formatter.format(_endsAt),
                  onPressed: () async {
                    final value = await _pickDateTime(_endsAt);
                    if (value != null && mounted) {
                      setState(() => _endsAt = value);
                    }
                  },
                );
                if (constraints.maxWidth < 620) {
                  return Column(
                    children: [start, const SizedBox(height: 8), end],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: start),
                    const SizedBox(width: 12),
                    Expanded(child: end),
                  ],
                );
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(loc.quotaFreePeriodEnabled),
              subtitle: Text(loc.quotaFreePeriodAutomaticHint),
              value: _enabled,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _enabled = value),
            ),
            AdaptiveButtonBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              children: [
                if (_editingId != null)
                  TextButton(
                    onPressed: _saving ? null : () => setState(_resetForm),
                    child: AdaptiveButtonLabel(loc.cancel),
                  ),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: AdaptiveButtonLabel(loc.save),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  const _DateTimeButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.event_outlined),
    label: Align(
      alignment: Alignment.centerLeft,
      child: Text('$label\n$value'),
    ),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(58),
      alignment: Alignment.centerLeft,
    ),
  );
}

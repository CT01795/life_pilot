import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/service_subscription.dart';
import 'package:life_pilot/subscription/subscription_quota_presentation.dart';
import 'package:life_pilot/utils/decimal_input_formatter.dart';
import 'package:life_pilot/vendor/service_vendor_account.dart';

class AdminSpecialAuthorizationDialog extends StatefulWidget {
  const AdminSpecialAuthorizationDialog({
    required this.email,
    this.vendor = false,
    super.key,
  });

  final String email;
  final bool vendor;

  @override
  State<AdminSpecialAuthorizationDialog> createState() =>
      _AdminSpecialAuthorizationDialogState();
}

class _AdminSpecialAuthorizationDialogState
    extends State<AdminSpecialAuthorizationDialog> {
  final _form = GlobalKey<FormState>();
  final _quotas = <String, int>{};
  DateTime? _expiry;
  int _fee = 0;
  bool _saving = false;
  String? _error;
  String _storage = 'cloud';

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _expiry?.subtract(const Duration(seconds: 1)) ?? now,
      firstDate: DateUtils.dateOnly(now),
      lastDate: DateTime(now.year + 20, 12, 31),
    );
    if (!mounted || day == null) return;
    setState(() => _expiry = DateTime(day.year, day.month, day.day + 1));
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final loc = AppLocalizations.of(context)!;
    final expiry = _expiry;
    if (expiry == null || !expiry.isAfter(DateTime.now())) {
      setState(() => _error = loc.adminSubscriptionExpiryMustBeFuture);
      return;
    }
    _form.currentState!.save();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.vendor) {
        await ServiceVendorAccount().addSpecialAuthorization(
          email: widget.email,
          endsAt: expiry,
          feeTwd: _fee,
          quotas: Map.of(_quotas),
        );
      } else {
        await ServiceSubscription().addPersonalSpecialAuthorization(
          email: widget.email,
          storagePlan: _storage,
          endsAt: expiry,
          feeTwd: _fee,
          quotas: Map.of(_quotas),
        );
      }
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = loc.adminSubscriptionSaveFailed(error.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final labels = widget.vendor
        ? {
            'event_quota': loc.recommendEvent,
            'attraction_quota': loc.recommendPlaces,
            'image_megabytes': loc.adminPricingImageQuota,
            'analytics_days': loc.vendorAnalyticsDays,
          }
        : _storage == 'local'
        ? const <String, String>{}
        : {
            'calendar_events': loc.adminPricingCalendarQuota,
            'accounting_detail': loc.adminPricingAccountingQuota,
            'point_record_detail': loc.adminPricingPointQuota,
            'memory_trace': loc.adminPricingMemoryQuota,
            'game_questions': loc.adminPricingGameQuota,
            'calendar_shares': loc.adminPricingShareQuota,
            'recommended_events': loc.recommendEvent,
            'recommended_attractions': loc.recommendPlaces,
            'image_bytes': loc.adminPricingImageQuota,
            'answer_history_days': loc.adminPricingAnswerDays,
          };
    // The stored expiry is exclusive; show the last day of access.
    final expiryDay = _expiry?.subtract(const Duration(seconds: 1));
    final dates = MaterialLocalizations.of(context);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(loc.adminSpecialAuthorization),
        scrollable: true,
        content: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.email),
              if (!widget.vendor)
                DropdownButtonFormField<String>(
                  initialValue: _storage,
                  decoration: InputDecoration(
                    labelText: loc.adminSubscriptionStoragePlan,
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
                      : (value) {
                          if (value != null) setState(() => _storage = value);
                        },
                ),
              TextButton.icon(
                onPressed: _saving ? null : _chooseDate,
                icon: const Icon(Icons.event),
                label: Text(
                  expiryDay == null
                      ? loc.adminSubscriptionExpiry
                      : expiryDay.year == DateTime.now().year
                      ? dates.formatMediumDate(expiryDay)
                      : dates.formatFullDate(expiryDay),
                ),
              ),
              _number(
                loc.adminSpecialAuthorizationFee,
                (value) => _fee = value,
                initialValue: '0',
              ),
              if (!widget.vendor && _storage == 'local')
                Text('${loc.dataStorageLocal} · ${loc.quotaNotLimited}'),
              for (final entry in labels.entries)
                _number(
                  entry.value,
                  (value) {
                    _quotas[entry.key] = entry.key == 'image_bytes'
                        ? value * 1048576
                        : value;
                  },
                  fieldKey: entry.key,
                  max: entry.key == 'image_bytes' ? 2047 : 2147483647,
                ),
              if (_error case final error?)
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(loc.save),
          ),
        ],
      ),
    );
  }

  Widget _number(
    String label,
    ValueChanged<int> onSaved, {
    int max = 2147483647,
    String? initialValue,
    String? fieldKey,
  }) => TextFormField(
    key: fieldKey == null ? null : ValueKey(fieldKey),
    initialValue: initialValue,
    enabled: !_saving,
    keyboardType: TextInputType.number,
    inputFormatters: const [GroupedIntegerInputFormatter()],
    decoration: InputDecoration(labelText: label),
    validator: (raw) {
      final value = GroupedIntegerInputFormatter.tryParse(raw);
      return value != null && value >= 0 && value <= max
          ? null
          : '0–${formatSubscriptionNumber(AppLocalizations.of(context)!, max)}';
    },
    onSaved: (raw) => onSaved(GroupedIntegerInputFormatter.tryParse(raw)!),
  );
}

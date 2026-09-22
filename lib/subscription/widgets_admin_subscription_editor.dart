import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/service_subscription.dart';
import 'package:life_pilot/utils/const.dart';

class AdminSubscriptionEditor extends StatefulWidget {
  const AdminSubscriptionEditor({this.onSaved, super.key});

  final VoidCallback? onSaved;

  @override
  State<AdminSubscriptionEditor> createState() =>
      _AdminSubscriptionEditorState();
}

class _AdminSubscriptionEditorState extends State<AdminSubscriptionEditor> {
  final _email = TextEditingController();
  final _note = TextEditingController();
  final _extensionDays = TextEditingController(text: '90');
  late Future<List<SubscriptionPricingVersion>> _versions;
  String _plan = 'plus';
  String _storagePlan = 'cloud';
  String? _versionId;
  int _multiplier = 1;
  DateTime? _expiry = DateTime.now().add(const Duration(days: 90));
  bool _saving = false;
  bool _additive = false;
  Map<String, dynamic>? _lookedUpSubscription;
  bool _lookupLoading = false;
  bool _hasLookedUp = false;
  String? _lookedUpEmail;

  @override
  void initState() {
    super.initState();
    _versions = ServiceSubscription().fetchPricingVersions();
  }

  @override
  void dispose() {
    _email.dispose();
    _note.dispose();
    _extensionDays.dispose();
    super.dispose();
  }

  Future<void> _save(List<SubscriptionPricingVersion> versions) async {
    final loc = AppLocalizations.of(context)!;
    if (_email.text.trim().isEmpty || _saving) return;
    if (!_lookupMatchesCurrentEmail) {
      _show(loc.adminSubscriptionLookupRequired);
      return;
    }
    final matchingVersions = versions
        .where((version) => version.storagePlan == _storagePlan)
        .toList(growable: false);
    final selectedVersion =
        matchingVersions.any((version) => version.id == _versionId)
        ? _versionId
        : (matchingVersions.isEmpty ? null : matchingVersions.first.id);
    if (_plan == 'plus' && selectedVersion == null) {
      _show(loc.adminSubscriptionNoPricing);
      return;
    }
    setState(() => _saving = true);
    try {
      final service = ServiceSubscription();
      if (_additive && _plan == 'plus') {
        await service.addUserEntitlementAsAdmin(
          email: _email.text,
          storagePlan: _storagePlan,
          pricingVersionId: selectedVersion!,
          multiplier: _multiplier,
          endsAt: _expiry!,
          note: _note.text,
        );
      } else {
        await service.setUserSubscriptionV2AsAdmin(
          email: _email.text,
          plan: _plan,
          storagePlan: _storagePlan,
          pricingVersionId: _plan == 'free' ? null : selectedVersion,
          multiplier: _multiplier,
          expiresAt: _plan == 'free' ? null : _expiry,
          note: _note.text,
        );
      }
      if (!mounted) return;
      _show(loc.adminSubscriptionSaved);
      widget.onSaved?.call();
      await _lookupSubscription();
    } catch (error) {
      if (mounted) _show(loc.adminSubscriptionSaveFailed(error.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return FutureBuilder<List<SubscriptionPricingVersion>>(
      future: _versions,
      builder: (context, snapshot) {
        final versions = snapshot.data ?? const <SubscriptionPricingVersion>[];
        final matchingVersions = versions
            .where((version) => version.storagePlan == _storagePlan)
            .toList(growable: false);
        final selectedVersion =
            matchingVersions.any((version) => version.id == _versionId)
            ? _versionId
            : (matchingVersions.isEmpty ? null : matchingVersions.first.id);
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            leading: const CircleAvatar(
              child: Icon(Icons.manage_accounts_outlined),
            ),
            title: Text(loc.adminSubscriptionTitle),
            subtitle: Text(loc.adminSubscriptionSubtitle),
            childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => _clearLookupWhenEmailChanged(),
                      decoration: InputDecoration(
                        labelText: loc.adminSubscriptionEmail,
                        prefixIcon: const Icon(Icons.alternate_email),
                      ),
                    ),
                  ),
                  Gaps.w8,
                  IconButton(
                    tooltip: loc.search,
                    onPressed: _lookupLoading ? null : _lookupSubscription,
                    icon: _lookupLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                  ),
                ],
              ),
              if (_subscriptionExists)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(
                    '${_lookedUpSubscription!['plan'] ?? 'free'} · '
                    '${_lookedUpSubscription!['storage_plan'] ?? 'cloud'}',
                  ),
                  subtitle: Text(
                    '${_lookedUpSubscription!['status'] ?? '-'} · '
                    '${_lookedUpSubscription!['expires_at'] ?? '-'}',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: loc.edit,
                        onPressed: _saving
                            ? null
                            : () => _loadSubscriptionIntoForm(versions),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: loc.delete,
                        onPressed: _saving ? null : _deleteSubscription,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              if (_lookupMatchesCurrentEmail && _lookedUpSubscription == null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_off_outlined),
                  title: Text(loc.adminSubscriptionUserNotFound),
                ),
              if (_lookedUpUserExists && !_subscriptionExists)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_add_alt_1_outlined),
                  title: Text(loc.adminSubscriptionNotFound),
                  subtitle: Text(loc.adminSubscriptionNotFoundCreate),
                ),
              Gaps.h12,
              LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth < 320
                    ? DropdownButtonFormField<String>(
                        initialValue: _plan,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: loc.adminSubscriptionPlan,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'free',
                            child: Text(loc.adminSubscriptionFree),
                          ),
                          DropdownMenuItem(
                            value: 'plus',
                            child: Text(loc.adminSubscriptionPaid),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) _setPlan(value);
                        },
                      )
                    : SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'free',
                            label: Text(loc.adminSubscriptionFree),
                          ),
                          ButtonSegment(
                            value: 'plus',
                            label: Text(loc.adminSubscriptionPaid),
                          ),
                        ],
                        selected: {_plan},
                        onSelectionChanged: (value) => _setPlan(value.first),
                      ),
              ),
              if (_plan == 'free')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.info_outline),
                    title: Text(loc.adminSubscriptionNoExpiry),
                    subtitle: Text(loc.adminSubscriptionInactiveWarning),
                  ),
                )
              else ...[
                Gaps.h12,
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(loc.adminSubscriptionAddQuota),
                  subtitle: Text(loc.adminSubscriptionAddQuotaHint),
                  value: _additive,
                  onChanged: (value) => setState(() => _additive = value),
                ),
                LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth < 380
                      ? DropdownButtonFormField<String>(
                          initialValue: _storagePlan,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: loc.adminSubscriptionStoragePlan,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'cloud',
                              child: Text(loc.adminSubscriptionCloud),
                            ),
                            DropdownMenuItem(
                              value: 'local',
                              child: Text(loc.adminSubscriptionLocal),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _storagePlan = value;
                                _versionId = null;
                              });
                            }
                          },
                        )
                      : SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'cloud',
                              icon: const Icon(Icons.cloud_outlined),
                              label: Text(loc.adminSubscriptionCloud),
                            ),
                            ButtonSegment(
                              value: 'local',
                              icon: const Icon(Icons.devices_outlined),
                              label: Text(loc.adminSubscriptionLocal),
                            ),
                          ],
                          selected: {_storagePlan},
                          onSelectionChanged: (value) => setState(() {
                            _storagePlan = value.first;
                            _versionId = null;
                          }),
                        ),
                ),
                Gaps.h12,
                DropdownButtonFormField<String>(
                  key: ValueKey(selectedVersion),
                  initialValue: selectedVersion,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: loc.adminSubscriptionPricingVersion,
                    prefixIcon: const Icon(Icons.history),
                  ),
                  items: matchingVersions
                      .map(
                        (version) => DropdownMenuItem(
                          value: version.id,
                          child: Text(
                            '${version.name} · NT\$${version.quarterlyPriceTwd}/季',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  selectedItemBuilder: (context) => matchingVersions
                      .map(
                        (version) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${version.name} · NT\$${version.quarterlyPriceTwd}/季',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: matchingVersions.isEmpty
                      ? null
                      : (value) => setState(() => _versionId = value),
                ),
                Gaps.h12,
                DropdownButtonFormField<int>(
                  initialValue: _multiplier,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: loc.adminSubscriptionMultiplier,
                    prefixIcon: const Icon(Icons.multiple_stop),
                  ),
                  items: List.generate(
                    10,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text(loc.adminSubscriptionTimes(index + 1)),
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => _multiplier = value ?? 1),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_available_outlined),
                  title: Text(loc.adminSubscriptionExpiry),
                  subtitle: Text(
                    _expiry == null
                        ? '-'
                        : MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(_expiry!),
                  ),
                  onTap: _pickExpiry,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _extensionDays,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: loc.adminSubscriptionExtensionDays,
                          suffixText: loc.days,
                        ),
                      ),
                    ),
                    Gaps.w8,
                    Tooltip(
                      message: !_lookupMatchesCurrentEmail
                          ? loc.adminSubscriptionLookupRequired
                          : !_subscriptionExists
                          ? loc.adminSubscriptionNotFound
                          : loc.adminSubscriptionExtend,
                      child: TextButton.icon(
                        onPressed:
                            _saving ||
                                !_lookupMatchesCurrentEmail ||
                                !_subscriptionExists
                            ? null
                            : _extendSubscription,
                        icon: const Icon(Icons.more_time),
                        label: Text(loc.adminSubscriptionExtend),
                      ),
                    ),
                  ],
                ),
              ],
              TextField(
                controller: _note,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: loc.adminSubscriptionNote,
                  alignLabelWithHint: true,
                ),
              ),
              Gaps.h16,
              SizedBox(
                width: double.infinity,
                child: Tooltip(
                  message: _lookupMatchesCurrentEmail
                      ? _lookedUpUserExists
                            ? loc.adminSubscriptionSave
                            : loc.adminSubscriptionUserNotFound
                      : loc.adminSubscriptionLookupRequired,
                  child: FilledButton.icon(
                    onPressed:
                        _saving ||
                            !_lookupMatchesCurrentEmail ||
                            !_lookedUpUserExists
                        ? null
                        : () => _save(versions),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(loc.adminSubscriptionSave),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickExpiry() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _expiry ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 36500)),
    );
    if (value != null) setState(() => _expiry = value);
  }

  Future<void> _lookupSubscription() async {
    final email = _normalizedEmail;
    if (email.isEmpty) return;
    setState(() {
      _lookupLoading = true;
      _hasLookedUp = false;
      _lookedUpEmail = null;
      _lookedUpSubscription = null;
    });
    try {
      final result = await ServiceSubscription().fetchUserSubscriptionAsAdmin(
        email: email,
      );
      if (mounted) {
        setState(() {
          _lookedUpSubscription = result;
          _lookedUpEmail = email;
          _hasLookedUp = true;
        });
      }
    } catch (error) {
      if (mounted) {
        _show(
          AppLocalizations.of(
            context,
          )!.adminSubscriptionSaveFailed(error.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _lookupLoading = false);
    }
  }

  Future<void> _extendSubscription() async {
    final loc = AppLocalizations.of(context)!;
    final days = int.tryParse(_extensionDays.text.trim());
    if (days == null || days < 1 || days > 3650) {
      _show(loc.adminSubscriptionInvalidExtensionDays);
      return;
    }
    setState(() => _saving = true);
    try {
      await ServiceSubscription().extendUserSubscriptionAsAdmin(
        email: _email.text,
        days: days,
      );
      if (!mounted) return;
      _show(loc.adminSubscriptionExtendedDays(days));
      widget.onSaved?.call();
      await _lookupSubscription();
    } catch (error) {
      if (mounted) _show(loc.adminSubscriptionSaveFailed(error.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _loadSubscriptionIntoForm(List<SubscriptionPricingVersion> versions) {
    if (!_subscriptionExists) return;
    final subscription = _lookedUpSubscription!;
    final plan = subscription['plan']?.toString() ?? 'free';
    final storagePlan = subscription['storage_plan']?.toString() ?? 'cloud';
    final pricingVersionId = subscription['pricing_version_id']?.toString();
    final parsedExpiry = DateTime.tryParse(
      subscription['current_period_end']?.toString() ??
          subscription['expires_at']?.toString() ??
          '',
    );
    final versionExists = versions.any(
      (version) =>
          version.id == pricingVersionId && version.storagePlan == storagePlan,
    );
    setState(() {
      _plan = plan;
      _storagePlan = storagePlan;
      _versionId = versionExists ? pricingVersionId : null;
      _multiplier = (subscription['quota_multiplier'] as num?)?.toInt() ?? 1;
      _expiry = plan == 'free'
          ? null
          : (parsedExpiry?.toLocal() ??
                DateTime.now().add(const Duration(days: 90)));
      _note.text = subscription['admin_note']?.toString() ?? '';
      _additive = false;
    });
    _show(AppLocalizations.of(context)!.adminSubscriptionLoadedForEditing);
  }

  Future<void> _deleteSubscription() async {
    if (!_subscriptionExists || _saving) return;
    final loc = AppLocalizations.of(context)!;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(loc.adminSubscriptionDeleteTitle),
            content: Text(
              loc.adminSubscriptionDeleteConfirmation(_normalizedEmail),
            ),
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
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    try {
      await ServiceSubscription().deleteUserSubscriptionAsAdmin(
        email: _normalizedEmail,
      );
      if (!mounted) return;
      _show(loc.adminSubscriptionDeleted);
      widget.onSaved?.call();
      await _lookupSubscription();
    } catch (error) {
      if (mounted) _show(loc.adminSubscriptionSaveFailed(error.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setPlan(String value) {
    setState(() {
      _plan = value;
      _expiry = _plan == 'free'
          ? null
          : (_expiry ?? DateTime.now().add(const Duration(days: 90)));
    });
  }

  String get _normalizedEmail => _email.text.trim().toLowerCase();

  bool get _lookupMatchesCurrentEmail =>
      _hasLookedUp && _lookedUpEmail == _normalizedEmail;

  bool get _lookedUpUserExists =>
      _lookupMatchesCurrentEmail && _lookedUpSubscription != null;

  bool get _subscriptionExists =>
      _lookedUpUserExists && _lookedUpSubscription!['plan'] != null;

  void _clearLookupWhenEmailChanged() {
    if (!_hasLookedUp &&
        _lookedUpSubscription == null &&
        _lookedUpEmail == null) {
      return;
    }
    setState(() {
      _hasLookedUp = false;
      _lookedUpEmail = null;
      _lookedUpSubscription = null;
    });
  }
}

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
  late Future<List<SubscriptionPricingVersion>> _versions;
  String _plan = 'plus';
  String _storagePlan = 'cloud';
  String? _versionId;
  int _multiplier = 1;
  DateTime? _expiry = DateTime.now().add(const Duration(days: 90));
  bool _saving = false;
  bool _additive = false;

  @override
  void initState() {
    super.initState();
    _versions = ServiceSubscription().fetchPricingVersions();
  }

  @override
  void dispose() {
    _email.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(List<SubscriptionPricingVersion> versions) async {
    final loc = AppLocalizations.of(context)!;
    if (_email.text.trim().isEmpty || _saving) return;
    final selectedVersion =
        _versionId ?? (versions.isEmpty ? null : versions.first.id);
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
    } catch (error) {
      if (mounted) _show(loc.adminSubscriptionSaveFailed(error.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return FutureBuilder<List<SubscriptionPricingVersion>>(
      future: _versions,
      builder: (context, snapshot) {
        final versions = snapshot.data ?? const <SubscriptionPricingVersion>[];
        final selectedVersion =
            _versionId ?? (versions.isEmpty ? null : versions.first.id);
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            leading:
                const CircleAvatar(child: Icon(Icons.manage_accounts_outlined)),
            title: Text(loc.adminSubscriptionTitle),
            subtitle: Text(loc.adminSubscriptionSubtitle),
            childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: loc.adminSubscriptionEmail,
                  prefixIcon: const Icon(Icons.alternate_email),
                ),
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
                              setState(() => _storagePlan = value);
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
                          onSelectionChanged: (value) =>
                              setState(() => _storagePlan = value.first),
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
                  items: versions
                      .map((version) => DropdownMenuItem(
                            value: version.id,
                            child: Text(
                              '${version.name} · NT\$${version.quarterlyPriceTwd}/季',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  selectedItemBuilder: (context) => versions
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
                  onChanged: (value) => setState(() => _versionId = value),
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
                  subtitle: Text(_expiry == null
                      ? '-'
                      : MaterialLocalizations.of(context)
                          .formatMediumDate(_expiry!)),
                  onTap: _pickExpiry,
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
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _save(versions),
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(loc.adminSubscriptionSave),
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

  void _setPlan(String value) {
    setState(() {
      _plan = value;
      _expiry = _plan == 'free'
          ? null
          : (_expiry ?? DateTime.now().add(const Duration(days: 90)));
    });
  }
}

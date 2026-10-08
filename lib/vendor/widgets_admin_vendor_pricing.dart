import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/vendor/model_vendor_account.dart';
import 'package:life_pilot/vendor/service_vendor_account.dart';
import 'package:life_pilot/vendor/vendor_plan_labels.dart';

class AdminVendorPricing extends StatefulWidget {
  const AdminVendorPricing({super.key});

  @override
  State<AdminVendorPricing> createState() => _AdminVendorPricingState();
}

class _AdminVendorPricingState extends State<AdminVendorPricing> {
  final _service = ServiceVendorAccount();
  final _version = TextEditingController();
  final _email = TextEditingController();
  final _note = TextEditingController();
  final _price = TextEditingController();
  final _eventQuota = TextEditingController();
  final _attractionQuota = TextEditingController();
  final _imageQuota = TextEditingController();
  final _analyticsDays = TextEditingController();
  final _multiplier = TextEditingController(text: '1');
  late Future<List<VendorPricingPlan>> _plans;
  String _planCode = 'partner';
  String? _selectedPricingId;
  DateTime _effectiveAt = DateTime.now();
  DateTime _periodEnd = DateTime.now().add(const Duration(days: 90));
  bool _savingPricing = false;
  bool _savingSubscription = false;
  String? _editingPricingId;
  String? _editingVersionName;

  @override
  void initState() {
    super.initState();
    _plans = _service.fetchPricingPlans();
  }

  @override
  void dispose() {
    for (final controller in [
      _version,
      _email,
      _note,
      _price,
      _eventQuota,
      _attractionQuota,
      _imageQuota,
      _analyticsDays,
      _multiplier,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _int(TextEditingController controller) =>
      int.tryParse(controller.text.trim());

  Future<void> _savePricing() async {
    final loc = AppLocalizations.of(context)!;
    final values = [
      _int(_price),
      _int(_eventQuota),
      _int(_attractionQuota),
      _int(_imageQuota),
      _int(_analyticsDays),
    ];
    if (_version.text.trim().isEmpty ||
        values.any((value) => value == null || value < 0)) {
      _message(loc.adminPricingRequired);
      return;
    }
    setState(() => _savingPricing = true);
    try {
      final createsNewVersion =
          _editingPricingId == null ||
          _version.text.trim().toLowerCase() !=
              _editingVersionName?.trim().toLowerCase();
      if (createsNewVersion) {
        await _service.createPricingVersionAsAdmin(
          planCode: _planCode,
          versionName: _version.text,
          effectiveAt: _effectiveAt,
          quarterlyPriceTwd: values[0]!,
          eventQuota: values[1]!,
          attractionQuota: values[2]!,
          imageMegabytes: values[3]!,
          analyticsDays: values[4]!,
        );
      } else {
        await _service.updatePricingVersionAsAdmin(
          pricingVersionId: _editingPricingId!,
          planCode: _planCode,
          versionName: _version.text,
          effectiveAt: _effectiveAt,
          quarterlyPriceTwd: values[0]!,
          eventQuota: values[1]!,
          attractionQuota: values[2]!,
          imageMegabytes: values[3]!,
          analyticsDays: values[4]!,
        );
      }
      if (!mounted) return;
      _message(
        createsNewVersion
            ? loc.adminVendorPricingCreated
            : loc.adminVendorPricingUpdated,
      );
      _resetPricingForm();
      setState(() => _plans = _service.fetchPricingPlans());
    } catch (error) {
      if (mounted) _message(loc.adminPricingCreateFailed(error.toString()));
    } finally {
      if (mounted) setState(() => _savingPricing = false);
    }
  }

  void _editPricing(VendorPricingPlan plan) {
    setState(() {
      _editingPricingId = plan.id;
      _editingVersionName = plan.versionName;
      _planCode = plan.code;
      _effectiveAt = plan.effectiveAt.toLocal();
      _version.text = plan.versionName;
      _price.text = '${plan.quarterlyPriceTwd}';
      _eventQuota.text = '${plan.eventQuota}';
      _attractionQuota.text = '${plan.attractionQuota}';
      _imageQuota.text = '${plan.imageMegabytes}';
      _analyticsDays.text = '${plan.analyticsDays}';
    });
  }

  void _resetPricingForm() {
    _editingPricingId = null;
    _editingVersionName = null;
    _planCode = 'partner';
    _effectiveAt = DateTime.now();
    _version.clear();
    _price.clear();
    _eventQuota.clear();
    _attractionQuota.clear();
    _imageQuota.clear();
    _analyticsDays.clear();
  }

  Future<void> _deletePricing(VendorPricingPlan plan) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.adminPricingDeleteTitle),
        content: Text(
          loc.adminPricingDeleteConfirmation(vendorPlanVersionName(loc, plan)),
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
    );
    if (confirmed != true || !mounted) return;
    setState(() => _savingPricing = true);
    try {
      await _service.deletePricingVersionAsAdmin(pricingVersionId: plan.id);
      if (!mounted) return;
      if (_editingPricingId == plan.id) _resetPricingForm();
      _message(loc.adminPricingDeleted);
      setState(() => _plans = _service.fetchPricingPlans());
    } catch (error) {
      if (mounted) {
        _message(
          error.toString().contains('pricing_version_in_use')
              ? loc.adminPricingDeleteInUse
              : loc.adminPricingCreateFailed(error.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPricing = false);
    }
  }

  Future<void> _saveSubscription() async {
    final loc = AppLocalizations.of(context)!;
    final multiplier = _int(_multiplier);
    if (_email.text.trim().isEmpty ||
        _selectedPricingId == null ||
        multiplier == null ||
        multiplier < 1) {
      _message(loc.adminPricingRequired);
      return;
    }
    setState(() => _savingSubscription = true);
    try {
      await _service.setSubscriptionAsAdmin(
        email: _email.text,
        pricingVersionId: _selectedPricingId!,
        quotaMultiplier: multiplier,
        currentPeriodEnd: _periodEnd,
        note: _note.text,
      );
      if (mounted) _message(loc.adminVendorSubscriptionSaved);
    } catch (error) {
      if (mounted) _message(loc.adminSubscriptionSaveFailed(error.toString()));
    } finally {
      if (mounted) setState(() => _savingSubscription = false);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.now().subtract(const Duration(days: 1)),
    lastDate: DateTime.now().add(const Duration(days: 3650)),
  );

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final date = MaterialLocalizations.of(context);
    return Column(
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            leading: const CircleAvatar(child: Icon(Icons.storefront)),
            title: Text(loc.adminVendorPricingTitle),
            subtitle: Text(loc.adminVendorPricingSubtitle),
            childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  loc.adminVendorExistingPlans,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Gaps.h8,
              FutureBuilder<List<VendorPricingPlan>>(
                future: _plans,
                builder: (context, snapshot) {
                  final plans = snapshot.data ?? const <VendorPricingPlan>[];
                  return Column(
                    children: plans
                        .map(
                          (plan) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.sell_outlined),
                            title: Text(
                              vendorPlanVersionName(loc, plan),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              loc.vendorQuarterlyPrice(plan.quarterlyPriceTwd),
                            ),
                            trailing: PopupMenuButton<String>(
                              enabled: !_savingPricing,
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).showMenuTooltip,
                              onSelected: (action) {
                                if (action == 'edit') _editPricing(plan);
                                if (action == 'delete') _deletePricing(plan);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(loc.edit),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(loc.delete),
                                ),
                              ],
                            ),
                            onTap: _savingPricing
                                ? null
                                : () => _editPricing(plan),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
              const Divider(height: 28),
              DropdownButtonFormField<String>(
                key: ValueKey(_planCode),
                initialValue: _planCode,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: loc.adminSubscriptionPlan,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'free',
                    child: Text(loc.vendorPlanFreeName),
                  ),
                  DropdownMenuItem(
                    value: 'partner',
                    child: Text(loc.vendorPlanPartnerName),
                  ),
                  DropdownMenuItem(
                    value: 'growth',
                    child: Text(loc.vendorPlanGrowthName),
                  ),
                ],
                onChanged: _savingPricing
                    ? null
                    : (value) => setState(() => _planCode = value ?? 'partner'),
              ),
              Gaps.h12,
              TextField(
                controller: _version,
                decoration: InputDecoration(
                  labelText: loc.adminPricingVersionName,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(loc.adminPricingEffectiveDate),
                subtitle: Text(date.formatMediumDate(_effectiveAt)),
                onTap: () async {
                  final value = await _pickDate(_effectiveAt);
                  if (value != null && mounted) {
                    setState(() => _effectiveAt = value);
                  }
                },
              ),
              _fields(loc),
              Gaps.h12,
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _savingPricing ? null : _savePricing,
                    icon: Icon(
                      _editingPricingId == null
                          ? Icons.add
                          : Icons.save_outlined,
                    ),
                    label: Text(
                      _editingPricingId == null
                          ? loc.adminPricingCreate
                          : loc.adminPricingUpdate,
                    ),
                  ),
                  if (_editingPricingId != null)
                    OutlinedButton(
                      onPressed: _savingPricing
                          ? null
                          : () => setState(_resetPricingForm),
                      child: Text(loc.cancel),
                    ),
                ],
              ),
            ],
          ),
        ),
        Gaps.h12,
        Card(
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
            title: Text(loc.adminVendorSubscriptionTitle),
            subtitle: Text(loc.adminVendorSubscriptionSubtitle),
            childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: loc.adminSubscriptionEmail,
                ),
              ),
              Gaps.h12,
              FutureBuilder<List<VendorPricingPlan>>(
                future: _plans,
                builder: (context, snapshot) {
                  final plans = snapshot.data ?? const <VendorPricingPlan>[];
                  return DropdownButtonFormField<String>(
                    initialValue:
                        plans.any((plan) => plan.id == _selectedPricingId)
                        ? _selectedPricingId
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: loc.adminSubscriptionPricingVersion,
                    ),
                    items: plans
                        .map(
                          (plan) => DropdownMenuItem(
                            value: plan.id,
                            child: Text(vendorPlanVersionName(loc, plan)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _savingSubscription
                        ? null
                        : (value) => setState(() => _selectedPricingId = value),
                  );
                },
              ),
              Gaps.h12,
              TextField(
                controller: _multiplier,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: loc.adminSubscriptionMultiplier,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_busy_outlined),
                title: Text(loc.adminSubscriptionExpiry),
                subtitle: Text(date.formatMediumDate(_periodEnd)),
                onTap: () async {
                  final value = await _pickDate(_periodEnd);
                  if (value != null && mounted) {
                    setState(() => _periodEnd = value);
                  }
                },
              ),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: loc.adminSubscriptionNote,
                ),
              ),
              Gaps.h12,
              FilledButton.icon(
                onPressed: _savingSubscription ? null : _saveSubscription,
                icon: const Icon(Icons.save_outlined),
                label: Text(loc.adminSubscriptionSave),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fields(AppLocalizations loc) {
    final fields = <(TextEditingController, String)>[
      (_price, loc.adminPricingQuarterlyPrice),
      (_eventQuota, loc.vendorActiveActivities),
      (_attractionQuota, loc.vendorActiveAttractions),
      (_imageQuota, loc.adminPricingImageQuota),
      (_analyticsDays, loc.vendorAnalyticsDays),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        itemCount: fields.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: constraints.maxWidth >= 720
              ? 3
              : constraints.maxWidth >= 440
              ? 2
              : 1,
          mainAxisExtent: 68,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemBuilder: (context, index) => TextField(
          controller: fields[index].$1,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: fields[index].$2),
        ),
      ),
    );
  }
}

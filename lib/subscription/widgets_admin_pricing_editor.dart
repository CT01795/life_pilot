import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/service_subscription.dart';
import 'package:life_pilot/utils/const.dart';

class AdminPricingVersionEditor extends StatefulWidget {
  const AdminPricingVersionEditor({this.onSaved, super.key});

  final VoidCallback? onSaved;

  @override
  State<AdminPricingVersionEditor> createState() =>
      _AdminPricingVersionEditorState();
}

class _AdminPricingVersionEditorState extends State<AdminPricingVersionEditor> {
  static const _cloudQuotaDefaults = <String, String>{
    'calendar': '300',
    'accounting': '300',
    'point': '300',
    'memory': '300',
    'game': '500',
    'share': '5',
    'image': '300',
    'answerDays': '365',
  };

  final _name = TextEditingController();
  final _values = <String, TextEditingController>{
    'price': TextEditingController(text: '129'),
    'calendar': TextEditingController(text: '300'),
    'accounting': TextEditingController(text: '300'),
    'point': TextEditingController(text: '300'),
    'memory': TextEditingController(text: '300'),
    'game': TextEditingController(text: '500'),
    'share': TextEditingController(text: '5'),
    'image': TextEditingController(text: '300'),
    'answerDays': TextEditingController(text: '365'),
  };
  DateTime _effectiveAt = DateTime.now();
  String _storagePlan = 'cloud';
  bool _saving = false;

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
      for (final entry in _cloudQuotaDefaults.entries) {
        _values[entry.key]!.text = value == 'local' ? '0' : entry.value;
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
      await ServiceSubscription().createPricingVersionAsAdmin(
        name: _name.text,
        storagePlan: _storagePlan,
        effectiveAt: _effectiveAt,
        quarterlyPrice: values['price']!,
        quotas: values.map((key, value) => MapEntry(key, value!)),
      );
      if (!mounted) return;
      _message(loc.adminPricingCreated);
      _name.clear();
      widget.onSaved?.call();
    } catch (error) {
      if (mounted) _message(loc.adminPricingCreateFailed(error.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final labels = {
      'price': loc.adminPricingQuarterlyPrice,
      'calendar': loc.adminPricingCalendarQuota,
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
            subtitle: Text(MaterialLocalizations.of(context)
                .formatMediumDate(_effectiveAt)),
            onTap: _pickEffectiveDate,
          ),
          DropdownButtonFormField<String>(
            initialValue: _storagePlan,
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
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.add_chart_outlined),
              label: Text(loc.adminPricingCreate),
            ),
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

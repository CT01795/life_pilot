import 'package:flutter/material.dart';
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
    if (_email.text.trim().isEmpty || _saving) return;
    final selectedVersion =
        _versionId ?? (versions.isEmpty ? null : versions.first.id);
    if (_plan == 'plus' && selectedVersion == null) {
      _show('请先建立收费版本');
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
      _show('使用者订阅设定已储存');
      widget.onSaved?.call();
    } catch (error) {
      if (mounted) _show('储存失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
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
            title: const Text('管理使用者订阅'),
            subtitle: const Text('套用付款当下的收费版本与额度'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: '使用者 Email',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              Gaps.h12,
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'free', label: Text('免费版')),
                  ButtonSegment(value: 'plus', label: Text('付费版')),
                ],
                selected: {_plan},
                onSelectionChanged: (value) => setState(() {
                  _plan = value.first;
                  _expiry = _plan == 'free'
                      ? null
                      : (_expiry ??
                          DateTime.now().add(const Duration(days: 90)));
                }),
              ),
              if (_plan == 'free')
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.info_outline),
                    title: Text('免费版没有到期日'),
                    subtitle: Text('连续 3 个月未新增或修改资料，帐号及云端资料会自动清除。'),
                  ),
                )
              else ...[
                Gaps.h12,
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('增加额度，不覆盖尚未到期的权益'),
                  subtitle: const Text('开启后会将这笔新版额度与旧版额度相加'),
                  value: _additive,
                  onChanged: (value) => setState(() => _additive = value),
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'cloud',
                        icon: Icon(Icons.cloud_outlined),
                        label: Text('云端版')),
                    ButtonSegment(
                        value: 'local',
                        icon: Icon(Icons.devices_outlined),
                        label: Text('本机不限量')),
                  ],
                  selected: {_storagePlan},
                  onSelectionChanged: (value) =>
                      setState(() => _storagePlan = value.first),
                ),
                Gaps.h12,
                DropdownButtonFormField<String>(
                  key: ValueKey(selectedVersion),
                  initialValue: selectedVersion,
                  decoration: const InputDecoration(
                      labelText: '收费版本', prefixIcon: Icon(Icons.history)),
                  items: versions
                      .map((version) => DropdownMenuItem(
                            value: version.id,
                            child: Text(
                                '${version.name} · NT\$${version.quarterlyPriceTwd}/季',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _versionId = value),
                ),
                Gaps.h12,
                DropdownButtonFormField<int>(
                  initialValue: _multiplier,
                  decoration: const InputDecoration(
                      labelText: '购买额度倍率',
                      prefixIcon: Icon(Icons.multiple_stop)),
                  items: List.generate(
                      10,
                      (index) => DropdownMenuItem(
                          value: index + 1, child: Text('${index + 1} 倍'))),
                  onChanged: (value) =>
                      setState(() => _multiplier = value ?? 1),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_available_outlined),
                  title: const Text('本次权益到期日'),
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
                decoration: const InputDecoration(
                    labelText: '补充说明', alignLabelWithHint: true),
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
                  label: const Text('储存订阅设定'),
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
}

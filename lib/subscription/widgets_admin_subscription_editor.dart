import 'package:flutter/material.dart';
import 'package:life_pilot/subscription/service_subscription.dart';

class AdminSubscriptionEditor extends StatefulWidget {
  const AdminSubscriptionEditor({super.key});

  @override
  State<AdminSubscriptionEditor> createState() =>
      _AdminSubscriptionEditorState();
}

class _AdminSubscriptionEditorState extends State<AdminSubscriptionEditor> {
  final _email = TextEditingController();
  final _note = TextEditingController();
  final _quotaControllers = <String, TextEditingController>{
    for (final key in [
      'calendar',
      'accounting',
      'point',
      'memory',
      'game',
      'share',
      'image'
    ])
      key: TextEditingController(),
  };
  String _plan = 'plus';
  DateTime _expiry = DateTime.now().add(const Duration(days: 365));
  bool _unlimited = false;
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    _note.dispose();
    for (final controller in _quotaControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _quota(String key) => int.tryParse(_quotaControllers[key]!.text.trim());

  Future<void> _save() async {
    if (_email.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await ServiceSubscription().setUserSubscriptionAsAdmin(
        email: _email.text,
        plan: _plan,
        expiresAt: _expiry,
        note: _note.text,
        unlimited: _unlimited,
        quotas: {for (final key in _quotaControllers.keys) key: _quota(key)},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('使用者訂閱設定已儲存')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const labels = {
      'calendar': '行事曆',
      'accounting': '記帳',
      'point': '積分',
      'memory': '回憶',
      'game': '自建題目',
      'share': '分享人數',
      'image': '圖片 MB',
    };
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.admin_panel_settings_outlined),
        title: const Text('管理使用者訂閱'),
        subtitle: const Text('設定到期日、備註與自訂額度'),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: '使用者 Email')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _plan,
            decoration: const InputDecoration(labelText: '方案'),
            items: const [
              DropdownMenuItem(value: 'free', child: Text('免費版')),
              DropdownMenuItem(value: 'plus', child: Text('Plus')),
            ],
            onChanged: (value) => setState(() => _plan = value ?? 'plus'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('訂閱到期日'),
            subtitle: Text(
                '${_expiry.year}-${_expiry.month.toString().padLeft(2, '0')}-${_expiry.day.toString().padLeft(2, '0')}'),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: () async {
              final value = await showDatePicker(
                context: context,
                initialDate: _expiry,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 36500)),
              );
              if (value != null) setState(() => _expiry = value);
            },
          ),
          TextField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '補充說明')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('無限額度'),
            subtitle: const Text('開啟後忽略下方個別額度'),
            value: _unlimited,
            onChanged: (value) => setState(() => _unlimited = value),
          ),
          if (!_unlimited)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: _quotaControllers.entries
                  .map((entry) => SizedBox(
                        width: 150,
                        child: TextField(
                          controller: entry.value,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: '${labels[entry.key]}（留空沿用方案）'),
                        ),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: const Text('儲存訂閱設定'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
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

  Future<void> _save() async {
    final values = {for (final key in _values.keys) key: _number(key)};
    if (_name.text.trim().isEmpty ||
        values.values.any((value) => value == null)) {
      _message('請填寫版本名稱與所有數字');
      return;
    }
    setState(() => _saving = true);
    try {
      await ServiceSubscription().createPricingVersionAsAdmin(
        name: _name.text,
        effectiveAt: _effectiveAt,
        quarterlyPrice: values['price']!,
        quotas: values.map((key, value) => MapEntry(key, value!)),
      );
      if (!mounted) return;
      _message('新收費版本已建立；舊版本與既有使用者權益保持不變');
      _name.clear();
      widget.onSaved?.call();
    } catch (error) {
      if (mounted) _message('建立失敗：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    const labels = {
      'price': '每季價格（TWD）',
      'calendar': '行事曆筆數',
      'accounting': '記帳明細',
      'point': '積分明細',
      'memory': '回憶紀錄',
      'game': '自建遊戲題目',
      'share': '行事曆分享人數',
      'image': '圖片容量（MB）',
      'answerDays': '答題紀錄保留天數',
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.price_change_outlined)),
        title: const Text('建立收費版本'),
        subtitle: const Text('新版本只影響之後付款或加購的權益'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '版本名稱',
              hintText: '例如 2026-Q4',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('生效日期'),
            subtitle: Text(MaterialLocalizations.of(context)
                .formatMediumDate(_effectiveAt)),
            onTap: _pickEffectiveDate,
          ),
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
              label: const Text('建立新版本'),
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

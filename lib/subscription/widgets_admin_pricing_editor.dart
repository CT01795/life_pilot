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
      _message('请填写版本名称与所有数字');
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
      _message('新收费版本已建立；旧版本与既有使用者权益保持不变');
      _name.clear();
      widget.onSaved?.call();
    } catch (error) {
      if (mounted) _message('建立失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    const labels = {
      'price': '每季价格（TWD）',
      'calendar': '行事历笔数',
      'accounting': '记帐明细',
      'point': '积分明细',
      'memory': '回忆纪录',
      'game': '自建游戏题目',
      'share': '行事历分享人数',
      'image': '图片容量（MB）',
      'answerDays': '答题纪录保留天数',
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.price_change_outlined)),
        title: const Text('建立收费版本'),
        subtitle: const Text('新版本只影响之后付款或加购的权益'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '版本名称',
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
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width >= 600 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: _values.entries
                .map((entry) => TextField(
                      controller: entry.value,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: labels[entry.key]),
                    ))
                .toList(),
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

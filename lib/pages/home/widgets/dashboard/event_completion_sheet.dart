import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/decimal_input_formatter.dart';
import 'package:life_pilot/utils/record_categories.dart';

class EventCompletionChoice {
  const EventCompletionChoice({
    required this.addToMemory,
    this.incomeValue,
    this.incomeCategory = RecordCategories.uncategorized,
    this.expenseValue,
    this.expenseCategory = RecordCategories.uncategorized,
    this.pointValue,
    this.pointCategory = RecordCategories.uncategorized,
    required this.recordedAt,
  });

  final bool addToMemory;
  final num? incomeValue;
  final String incomeCategory;
  final num? expenseValue;
  final String expenseCategory;
  final int? pointValue;
  final String pointCategory;
  final DateTime recordedAt;
}

Future<EventCompletionChoice?> showEventCompletionSheet(
  BuildContext context, {
  required String eventName,
  String? accountingAccountName,
  required String accountingCurrency,
  String? pointAccountName,
}) => showModalBottomSheet<EventCompletionChoice>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _EventCompletionSheet(
    eventName: eventName,
    accountingAccountName: accountingAccountName,
    accountingCurrency: accountingCurrency,
    pointAccountName: pointAccountName,
  ),
);

class _EventCompletionSheet extends StatefulWidget {
  const _EventCompletionSheet({
    required this.eventName,
    required this.accountingAccountName,
    required this.accountingCurrency,
    required this.pointAccountName,
  });

  final String eventName;
  final String? accountingAccountName;
  final String accountingCurrency;
  final String? pointAccountName;

  @override
  State<_EventCompletionSheet> createState() => _EventCompletionSheetState();
}

class _EventCompletionSheetState extends State<_EventCompletionSheet> {
  final _incomeController = TextEditingController();
  final _expenseController = TextEditingController();
  final _pointController = TextEditingController();
  bool _addToMemory = false;
  bool _addExpense = false;
  bool _addPoints = false;
  bool _pointsArePositive = true;
  String _incomeCategory = RecordCategories.uncategorized;
  String _expenseCategory = RecordCategories.uncategorized;
  String _pointCategory = RecordCategories.uncategorized;
  DateTime _recordDate = DateUtils.dateOnly(DateTime.now());
  TimeOfDay _recordTime = TimeOfDay.now();

  @override
  void dispose() {
    _incomeController.dispose();
    _expenseController.dispose();
    _pointController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Gaps.h16,
          Text(loc.completeEventTitle, style: textTheme.headlineSmall),
          Gaps.h8,
          Text(widget.eventName, style: textTheme.titleMedium),
          Gaps.h4,
          Text(loc.completeEventMessage),
          Gaps.h12,
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _addToMemory,
            title: Text(loc.memoryAdd),
            secondary: const Icon(Icons.auto_stories_outlined),
            controlAffinity: ListTileControlAffinity.trailing,
            onChanged: (value) {
              setState(() => _addToMemory = value ?? false);
            },
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _addExpense,
            title: Text(loc.accountRecords),
            subtitle: Text(
              widget.accountingAccountName ?? loc.accountListEmpty,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            secondary: const Icon(Icons.payments_outlined),
            controlAffinity: ListTileControlAffinity.trailing,
            onChanged: widget.accountingAccountName == null
                ? null
                : (value) {
                    setState(() => _addExpense = value ?? false);
                  },
          ),
          if (_addExpense) ...[
            Gaps.h8,
            TextField(
              controller: _incomeController,
              autofocus: false,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [DecimalInputFormatter()],
              decoration: InputDecoration(
                labelText: loc.eventIncome,
                suffixText: widget.accountingCurrency,
                prefixIcon: const Icon(Icons.add_circle_outline),
              ),
            ),
            Gaps.h12,
            DropdownButtonFormField<String>(
              initialValue: _incomeCategory,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: '${loc.eventIncome} · ${loc.recordPrimaryCategory}',
              ),
              items: RecordCategories.accounting
                  .where((category) => category != RecordCategories.reserved)
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(RecordCategories.label(loc, category)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _incomeCategory = value);
                }
              },
            ),
            Gaps.h12,
            TextField(
              controller: _expenseController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [DecimalInputFormatter()],
              decoration: InputDecoration(
                labelText: loc.eventExpense,
                suffixText: widget.accountingCurrency,
                prefixIcon: const Icon(Icons.remove_circle_outline),
              ),
            ),
            Gaps.h12,
            DropdownButtonFormField<String>(
              initialValue: _expenseCategory,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: '${loc.eventExpense} · ${loc.recordPrimaryCategory}',
              ),
              items: RecordCategories.accounting
                  .where((category) => category != RecordCategories.reserved)
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(RecordCategories.label(loc, category)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _expenseCategory = value);
                }
              },
            ),
          ],
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _addPoints,
            title: Text(loc.pointsRecord),
            subtitle: Text(
              widget.pointAccountName ?? loc.accountListEmpty,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            secondary: const Icon(Icons.stars_outlined),
            controlAffinity: ListTileControlAffinity.trailing,
            onChanged: widget.pointAccountName == null
                ? null
                : (value) => setState(() => _addPoints = value ?? false),
          ),
          if (_addPoints) ...[
            Gaps.h8,
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(loc.eventPointIncrease),
                ),
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: Text(loc.eventPointDecrease),
                ),
              ],
              selected: {_pointsArePositive},
              onSelectionChanged: (value) {
                setState(() => _pointsArePositive = value.first);
              },
            ),
            Gaps.h12,
            TextField(
              controller: _pointController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: loc.recordValue,
                suffixText: loc.pointsUnit,
                prefixIcon: Icon(
                  _pointsArePositive
                      ? Icons.add_circle_outline
                      : Icons.remove_circle_outline,
                ),
              ),
            ),
            Gaps.h12,
            DropdownButtonFormField<String>(
              initialValue: _pointCategory,
              isExpanded: true,
              decoration: InputDecoration(labelText: loc.recordPrimaryCategory),
              items: RecordCategories.points
                  .where((category) => category != RecordCategories.reserved)
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(RecordCategories.label(loc, category)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _pointCategory = value);
              },
            ),
          ],
          if (_addExpense || _addPoints) ...[
            Gaps.h12,
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(loc.recordDate),
                    trailing: TextButton(
                      onPressed: () async {
                        final value = await showDatePicker(
                          context: context,
                          initialDate: _recordDate,
                          firstDate: DateTime(1900),
                          lastDate: DateTime(2200),
                        );
                        if (value != null && mounted) {
                          setState(() => _recordDate = value);
                        }
                      },
                      child: Text(
                        DateFormat.yMMMd(loc.localeName).format(_recordDate),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: Text(loc.recordTime),
                    trailing: TextButton(
                      onPressed: () async {
                        final value = await showTimePicker(
                          context: context,
                          initialTime: _recordTime,
                        );
                        if (value != null && mounted) {
                          setState(() => _recordTime = value);
                        }
                      },
                      child: Text(_recordTime.format(context)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Gaps.h16,
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(loc.cancel),
                ),
              ),
              Gaps.w12,
              Expanded(
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _incomeController,
                    _expenseController,
                    _pointController,
                  ]),
                  builder: (context, _) {
                    final incomeValue = _parseAmount(_incomeController);
                    final expenseValue = _parseAmount(_expenseController);
                    final pointValue = int.tryParse(
                      _pointController.text.trim(),
                    );
                    final canSubmit = _canSubmit(
                      incomeValue: incomeValue,
                      expenseValue: expenseValue,
                      pointValue: pointValue,
                    );
                    return FilledButton.icon(
                      onPressed: canSubmit
                          ? () => Navigator.pop(
                              context,
                              EventCompletionChoice(
                                addToMemory: _addToMemory,
                                incomeValue: _addExpense ? incomeValue : null,
                                incomeCategory: _incomeCategory,
                                expenseValue: _addExpense ? expenseValue : null,
                                expenseCategory: _expenseCategory,
                                pointValue: _addPoints
                                    ? (_pointsArePositive
                                          ? pointValue
                                          : -pointValue!)
                                    : null,
                                pointCategory: _pointCategory,
                                recordedAt: DateTime(
                                  _recordDate.year,
                                  _recordDate.month,
                                  _recordDate.day,
                                  _recordTime.hour,
                                  _recordTime.minute,
                                ),
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(loc.confirm),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  num? _parseAmount(TextEditingController controller) =>
      num.tryParse(controller.text.trim().replaceAll(',', ''));

  bool _canSubmit({
    required num? incomeValue,
    required num? expenseValue,
    required int? pointValue,
  }) {
    final incomeText = _incomeController.text.trim();
    final expenseText = _expenseController.text.trim();
    final hasValidAccountingValue =
        (incomeValue != null && incomeValue > 0) ||
        (expenseValue != null && expenseValue > 0);
    final accountingValuesAreValid =
        (incomeText.isEmpty || (incomeValue != null && incomeValue > 0)) &&
        (expenseText.isEmpty || (expenseValue != null && expenseValue > 0));
    return (!_addExpense ||
            (hasValidAccountingValue && accountingValuesAreValid)) &&
        (!_addPoints || (pointValue != null && pointValue > 0));
  }
}

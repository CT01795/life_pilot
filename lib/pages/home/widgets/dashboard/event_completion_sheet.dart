import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/decimal_input_formatter.dart';
import 'package:life_pilot/utils/record_categories.dart';

class EventCompletionChoice {
  const EventCompletionChoice({
    required this.addToMemory,
    this.expenseValue,
    this.expenseCategory = RecordCategories.uncategorized,
    this.pointValue,
    this.pointCategory = RecordCategories.uncategorized,
  });

  final bool addToMemory;
  final num? expenseValue;
  final String expenseCategory;
  final int? pointValue;
  final String pointCategory;
}

Future<EventCompletionChoice?> showEventCompletionSheet(
  BuildContext context, {
  required String eventName,
  String? accountingAccountName,
  required String accountingCurrency,
  String? pointAccountName,
}) =>
    showModalBottomSheet<EventCompletionChoice>(
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
  final _expenseController = TextEditingController();
  final _pointController = TextEditingController();
  bool _addToMemory = false;
  bool _addExpense = false;
  bool _expenseIsIncome = false;
  bool _addPoints = false;
  bool _pointsArePositive = true;
  String _expenseCategory = RecordCategories.uncategorized;
  String _pointCategory = RecordCategories.uncategorized;

  @override
  void dispose() {
    _expenseController.dispose();
    _pointController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final expenseValue = num.tryParse(
      _expenseController.text.trim().replaceAll(',', ''),
    );
    final pointValue = int.tryParse(_pointController.text.trim());
    final canSubmit =
        (!_addExpense || (expenseValue != null && expenseValue > 0)) &&
            (!_addPoints || (pointValue != null && pointValue > 0));
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
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(loc.eventIncome),
                ),
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: Text(loc.eventExpense),
                ),
              ],
              selected: {_expenseIsIncome},
              onSelectionChanged: (value) {
                setState(() => _expenseIsIncome = value.first);
              },
            ),
            Gaps.h12,
            TextField(
              controller: _expenseController,
              autofocus: false,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [DecimalInputFormatter()],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: loc.recordValue,
                suffixText: widget.accountingCurrency,
                prefixIcon: Icon(_expenseIsIncome
                    ? Icons.add_circle_outline
                    : Icons.remove_circle_outline),
              ),
            ),
            Gaps.h12,
            DropdownButtonFormField<String>(
              initialValue: _expenseCategory,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: loc.recordPrimaryCategory,
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
                prefixIcon: Icon(_pointsArePositive
                    ? Icons.add_circle_outline
                    : Icons.remove_circle_outline),
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
                child: FilledButton.icon(
                  onPressed: canSubmit
                      ? () => Navigator.pop(
                            context,
                            EventCompletionChoice(
                              addToMemory: _addToMemory,
                              expenseValue: _addExpense
                                  ? (_expenseIsIncome
                                      ? expenseValue
                                      : -expenseValue!)
                                  : null,
                              expenseCategory: _expenseCategory,
                              pointValue: _addPoints
                                  ? (_pointsArePositive
                                      ? pointValue
                                      : -pointValue!)
                                  : null,
                              pointCategory: _pointCategory,
                            ),
                          )
                      : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(loc.confirm),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

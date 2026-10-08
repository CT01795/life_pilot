import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/decimal_input_formatter.dart';
import 'package:life_pilot/utils/record_categories.dart';
import 'package:life_pilot/utils/widgets/widgets_adaptive_button.dart';

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
  bool allowPoints = true,
  bool initialAccountingIsIncome = false,
  String initialAccountingCategory = RecordCategories.uncategorized,
  bool initialPointsArePositive = true,
  String initialPointCategory = RecordCategories.uncategorized,
}) => showModalBottomSheet<EventCompletionChoice>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _EventCompletionSheet(
    eventName: eventName,
    accountingAccountName: accountingAccountName,
    accountingCurrency: accountingCurrency,
    pointAccountName: pointAccountName,
    allowPoints: allowPoints,
    initialAccountingIsIncome: initialAccountingIsIncome,
    initialAccountingCategory: initialAccountingCategory,
    initialPointsArePositive: initialPointsArePositive,
    initialPointCategory: initialPointCategory,
  ),
);

class _EventCompletionSheet extends StatefulWidget {
  const _EventCompletionSheet({
    required this.eventName,
    required this.accountingAccountName,
    required this.accountingCurrency,
    required this.pointAccountName,
    required this.allowPoints,
    required this.initialAccountingIsIncome,
    required this.initialAccountingCategory,
    required this.initialPointsArePositive,
    required this.initialPointCategory,
  });

  final String eventName;
  final String? accountingAccountName;
  final String accountingCurrency;
  final String? pointAccountName;
  final bool allowPoints;
  final bool initialAccountingIsIncome;
  final String initialAccountingCategory;
  final bool initialPointsArePositive;
  final String initialPointCategory;

  @override
  State<_EventCompletionSheet> createState() => _EventCompletionSheetState();
}

class _EventCompletionSheetState extends State<_EventCompletionSheet> {
  final _accountingController = TextEditingController();
  final _pointController = TextEditingController();
  bool _addToMemory = false;
  bool _addAccounting = false;
  late bool _accountingIsIncome;
  bool _addPoints = false;
  late bool _pointsArePositive;
  late String _accountingCategory;
  late String _pointCategory;
  DateTime _recordDate = DateUtils.dateOnly(DateTime.now());
  TimeOfDay _recordTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _accountingIsIncome = widget.initialAccountingIsIncome;
    final accountingCategories = _accountingIsIncome
        ? RecordCategories.accountingIncome
        : RecordCategories.accountingExpense;
    _accountingCategory =
        accountingCategories.contains(widget.initialAccountingCategory)
        ? widget.initialAccountingCategory
        : RecordCategories.uncategorized;
    _pointsArePositive = widget.initialPointsArePositive;
    _pointCategory =
        RecordCategories.points.contains(widget.initialPointCategory) &&
            widget.initialPointCategory != RecordCategories.reserved
        ? widget.initialPointCategory
        : RecordCategories.uncategorized;
  }

  @override
  void dispose() {
    _accountingController.dispose();
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
            value: _addAccounting,
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
                    setState(() => _addAccounting = value ?? false);
                  },
          ),
          if (_addAccounting) ...[
            Gaps.h8,
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: Text(loc.eventExpense),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(loc.eventIncome),
                ),
              ],
              selected: {_accountingIsIncome},
              onSelectionChanged: (value) {
                if (value.isEmpty) return;
                setState(() {
                  _accountingIsIncome = value.first;
                  _accountingCategory = RecordCategories.uncategorized;
                });
              },
            ),
            Gaps.h12,
            TextField(
              controller: _accountingController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [DecimalInputFormatter()],
              decoration: InputDecoration(
                labelText: loc.recordValue,
                suffixText: widget.accountingCurrency,
                prefixIcon: Icon(
                  _accountingIsIncome
                      ? Icons.add_circle_outline
                      : Icons.remove_circle_outline,
                ),
              ),
            ),
            Gaps.h12,
            DropdownButtonFormField<String>(
              key: ValueKey(_accountingIsIncome),
              initialValue: _accountingCategory,
              isExpanded: true,
              decoration: InputDecoration(labelText: loc.recordPrimaryCategory),
              items:
                  (_accountingIsIncome
                          ? RecordCategories.accountingIncome
                          : RecordCategories.accountingExpense)
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(RecordCategories.label(loc, category)),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _accountingCategory = value);
                }
              },
            ),
          ],
          if (widget.allowPoints)
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
          if (widget.allowPoints && _addPoints) ...[
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
                if (value.isEmpty) return;
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
          if (_addAccounting || _addPoints) ...[
            Gaps.h12,
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _CompletionDateTimeRow(
                    icon: Icons.calendar_today_outlined,
                    label: loc.recordDate,
                    value: DateFormat.yMMMd(loc.localeName).format(_recordDate),
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
                  ),
                  _CompletionDateTimeRow(
                    icon: Icons.schedule_outlined,
                    label: loc.recordTime,
                    value: _recordTime.format(context),
                    onPressed: () async {
                      final value = await showTimePicker(
                        context: context,
                        initialTime: _recordTime,
                      );
                      if (value != null && mounted) {
                        setState(() => _recordTime = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
          Gaps.h16,
          AdaptiveButtonBar(
            alignment: MainAxisAlignment.end,
            overflowAlignment: OverflowBarAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: AdaptiveButtonLabel(loc.cancel),
              ),
              ListenableBuilder(
                listenable: Listenable.merge([
                  _accountingController,
                  _pointController,
                ]),
                builder: (context, _) {
                  final accountingValue = _parseAmount(_accountingController);
                  final pointValue = int.tryParse(_pointController.text.trim());
                  final canSubmit = _canSubmit(
                    accountingValue: accountingValue,
                    pointValue: pointValue,
                  );
                  return FilledButton.icon(
                    onPressed: canSubmit
                        ? () => Navigator.pop(
                            context,
                            EventCompletionChoice(
                              addToMemory: _addToMemory,
                              incomeValue: _addAccounting && _accountingIsIncome
                                  ? accountingValue
                                  : null,
                              incomeCategory: _accountingCategory,
                              expenseValue:
                                  _addAccounting && !_accountingIsIncome
                                  ? accountingValue
                                  : null,
                              expenseCategory: _accountingCategory,
                              pointValue: widget.allowPoints && _addPoints
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
                    label: AdaptiveButtonLabel(loc.confirm),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  num? _parseAmount(TextEditingController controller) =>
      num.tryParse(controller.text.trim().replaceAll(',', ''));

  bool _canSubmit({required num? accountingValue, required int? pointValue}) {
    return (!_addAccounting ||
            (accountingValue != null && accountingValue > 0)) &&
        (!_addPoints || (pointValue != null && pointValue > 0));
  }
}

class _CompletionDateTimeRow extends StatelessWidget {
  const _CompletionDateTimeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon),
            Gaps.w16,
            Expanded(child: Text(label)),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(onPressed: onPressed, child: Text(value)),
        ),
      ],
    ),
  );
}

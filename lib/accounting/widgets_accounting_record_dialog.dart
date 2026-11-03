import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/accounting/model_accounting_preview.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/record_categories.dart';
import 'package:life_pilot/utils/record_date_time.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/utils/decimal_input_formatter.dart';

Future<AccountingPreview?> showAccountingRecordDialog(
  BuildContext context,
  AccountingPreview record, {
  bool isNew = false,
  bool proposal = false,
  String? defaultCurrency,
}) async {
  bool isIncome = record.value > 0;
  final valueController = TextEditingController(
    text: isNew ? '' : NumberFormat('#,##0.####').format(record.value.abs()),
  );
  final descController = TextEditingController(text: record.description);
  String currency = currencyList.contains(record.currency)
      ? record.currency!
      : (currencyList.contains(defaultCurrency)
            ? defaultCurrency!
            : currencyList.first);
  DateTime selectedDate = record.date ?? DateTime.now();
  String primaryCategory = record.primaryCategory;
  final secondaryController = TextEditingController(
    text: record.secondaryCategory ?? '',
  );
  final loc = AppLocalizations.of(context)!;

  String? validationError;
  final result = await showDialog<AccountingPreview>(
    context: context,
    builder: (context) {
      // ✅ 使用 StatefulBuilder 來控制 dialog 內的狀態
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              proposal
                  ? loc.ledgerSubmitProposal
                  : (isNew ? loc.manualEntry : loc.editRecord),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    selected: {isIncome},
                    onSelectionChanged: (value) {
                      if (value.isEmpty) return;
                      setState(() {
                        isIncome = value.first;
                        final categories = isIncome
                            ? RecordCategories.accountingIncome
                            : RecordCategories.accountingExpense;
                        if (!categories.contains(primaryCategory) &&
                            primaryCategory != RecordCategories.reserved) {
                          primaryCategory = RecordCategories.uncategorized;
                        }
                      });
                    },
                  ),
                  Gaps.h8,
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(labelText: loc.description),
                  ),
                  TextField(
                    controller: valueController,
                    decoration: InputDecoration(
                      labelText: loc.recordValue,
                      errorText: validationError,
                      errorMaxLines: 3,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: const [DecimalInputFormatter()],
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(loc.recordDate),
                    subtitle: Text(
                      DateFormat.yMd(
                        Localizations.localeOf(context).toString(),
                      ).format(selectedDate),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = replaceRecordDate(
                            selectedDate,
                            picked,
                          );
                        });
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time),
                    title: Text(loc.recordTime),
                    subtitle: Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatTimeOfDay(TimeOfDay.fromDateTime(selectedDate)),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (picked == null) return;
                      setState(() {
                        selectedDate = replaceRecordTime(selectedDate, picked);
                      });
                    },
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey(isIncome),
                    isExpanded: true,
                    initialValue:
                        <String>{
                          if (!proposal) RecordCategories.reserved,
                          ...(isIncome
                              ? RecordCategories.accountingIncome
                              : RecordCategories.accountingExpense),
                        }.contains(primaryCategory)
                        ? primaryCategory
                        : RecordCategories.uncategorized,
                    decoration: InputDecoration(
                      labelText: loc.recordPrimaryCategory,
                    ),
                    items:
                        <String>[
                              if (!proposal) RecordCategories.reserved,
                              ...(isIncome
                                  ? RecordCategories.accountingIncome
                                  : RecordCategories.accountingExpense),
                            ]
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(
                                  RecordCategories.label(loc, category),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) primaryCategory = value;
                    },
                  ),
                  TextField(
                    controller: secondaryController,
                    decoration: InputDecoration(
                      labelText: loc.recordSecondaryCategory,
                    ),
                  ),
                  DropdownButton<String>(
                    value: currency,
                    isExpanded: true,
                    items: currencyList
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          currency = val; // ✅ 正確更新幣別
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text(loc.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  final v = tryParseNumValue(
                    valueController.text.replaceAll(',', ''),
                  );
                  if (v == null ||
                      !v.isFinite ||
                      v <= 0 ||
                      descController.text.trim().isEmpty) {
                    setState(() => validationError = loc.recordInputInvalid);
                    return;
                  }
                  Navigator.pop(
                    context,
                    record.copyWith(
                      value: isIncome ? v : -v,
                      description: descController.text.trim(),
                      currency: currency,
                      date: selectedDate,
                      primaryCategory: primaryCategory,
                      secondaryCategory: secondaryController.text.trim(),
                    ),
                  );
                },
                child: Text(proposal ? loc.ledgerSubmitProposal : loc.save),
              ),
            ],
          );
        },
      );
    },
  );

  return result;
}

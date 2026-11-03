import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/record_categories.dart';

/// Presentation only: callers choose direct edit, proposal, or no action.
class WidgetsLedgerRecordTile extends StatelessWidget {
  const WidgetsLedgerRecordTile({
    required this.description,
    required this.displayTime,
    required this.primaryCategory,
    required this.value,
    required this.formatter,
    this.currency,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  final String description;
  final String displayTime;
  final String primaryCategory;
  final num? value;
  final NumberFormat formatter;
  final String? currency;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final amount = value;
    final formatted = amount == null
        ? '—'
        : '${amount > 0 ? '+' : ''}${formatter.format(amount)} ${currency ?? ''}'
              .trim();
    return ListTile(
      title: Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              '$displayTime  [${RecordCategories.label(loc, primaryCategory)}]',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              formatted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: amount == null
                    ? null
                    : amount >= 0
                    ? Colors.green
                    : Colors.red,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      trailing: onDelete == null
          ? null
          : IconButton(
              tooltip: loc.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
      onTap: onEdit,
    );
  }
}

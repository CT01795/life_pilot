import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/stock/stock_display_formats.dart';

/// Date-picker View only. Availability and data loading belong to Controller.
class WidgetsStockDateSelector extends StatelessWidget {
  const WidgetsStockDateSelector({
    super.key,
    required this.selectedDate,
    required this.latestAvailableDate,
    required this.loading,
    required this.enabled,
    required this.onSelected,
  });
  final DateTime? selectedDate;
  final DateTime? latestAvailableDate;
  final bool loading;
  final bool enabled;
  final Future<void> Function(DateTime) onSelected;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final selected = selectedDate ?? now;
    final latest = latestAvailableDate ?? now;
    final label =
        '${loc.stockSelectDate}: ${StockDisplayFormats.forLocale(loc.localeName).date(selected)}';
    return Tooltip(
      message: label,
      child: OutlinedButton.icon(
        onPressed: !enabled
            ? null
            : () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selected,
                  firstDate: DateTime(2000),
                  lastDate: latest,
                );
                if (!context.mounted || picked == null) return;
                await onSelected(picked);
              },
        icon: loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.calendar_month_outlined),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

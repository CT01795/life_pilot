import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class VendorSubmissionHub extends StatelessWidget {
  const VendorSubmissionHub({
    super.key,
    required this.submitLabel,
    required this.showOnlyMySubmissions,
    required this.onSubmit,
    required this.onFilterChanged,
  });

  final String submitLabel;
  final bool showOnlyMySubmissions;
  final VoidCallback onSubmit;
  final ValueChanged<bool> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    const actionSize = Size(72, 48);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: submitLabel,
            child: SizedBox.fromSize(
              size: actionSize,
              child: FilledButton.tonal(
                onPressed: onSubmit,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(loc.vendorSubmitShort),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment<bool>(
                value: true,
                label: Text(loc.vendorMineShort),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text(loc.vendorAllShort),
              ),
            ],
            selected: {showOnlyMySubmissions},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              onFilterChanged(selection.first);
            },
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(actionSize),
              maximumSize: const WidgetStatePropertyAll(actionSize),
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              textStyle: WidgetStatePropertyAll(
                Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

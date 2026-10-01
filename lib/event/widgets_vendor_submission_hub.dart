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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.tonalIcon(
            onPressed: onSubmit,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(submitLabel),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: () => onFilterChanged(!showOnlyMySubmissions),
            icon: Icon(
              showOnlyMySubmissions
                  ? Icons.inventory_2
                  : Icons.inventory_2_outlined,
              size: 18,
            ),
            label: Text(
              showOnlyMySubmissions
                  ? loc.vendorMySubmissions
                  : loc.vendorAllActivities,
            ),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }
}

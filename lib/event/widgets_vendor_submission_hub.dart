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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onSubmit,
                    icon: const Icon(Icons.add),
                    label: Text(submitLabel),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onFilterChanged(!showOnlyMySubmissions),
                    icon: Icon(
                      showOnlyMySubmissions
                          ? Icons.inventory_2
                          : Icons.inventory_2_outlined,
                    ),
                    label: Text(
                      showOnlyMySubmissions
                          ? loc.vendorMySubmissions
                          : loc.vendorAllActivities,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
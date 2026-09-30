import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';

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
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Card(
        elevation: 0,
        color: colors.primaryContainer.withValues(alpha: 0.55),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    child: const Icon(Icons.campaign_outlined),
                  ),
                  Gaps.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.vendorSubmissionTitle,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Gaps.h4,
                        Text(loc.vendorSubmissionDescription),
                      ],
                    ),
                  ),
                ],
              ),
              Gaps.h12,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _BenefitChip(
                    icon: Icons.public,
                    label: loc.vendorSubmissionBenefitReach,
                  ),
                  _BenefitChip(
                    icon: Icons.edit_calendar_outlined,
                    label: loc.vendorSubmissionBenefitManage,
                  ),
                  _BenefitChip(
                    icon: Icons.verified_outlined,
                    label: loc.vendorSubmissionBenefitReview,
                  ),
                ],
              ),
              Gaps.h12,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onSubmit,
                    icon: const Icon(Icons.add),
                    label: Text(submitLabel),
                  ),
                  FilterChip(
                    selected: showOnlyMySubmissions,
                    avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: Text(
                      showOnlyMySubmissions
                          ? loc.vendorAllActivities
                          : loc.vendorMySubmissions,
                    ),
                    onSelected: onFilterChanged,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitChip extends StatelessWidget {
  const _BenefitChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 17),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

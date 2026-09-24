import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class RecommendationHighlights extends StatelessWidget {
  const RecommendationHighlights({
    super.key,
    required this.isFree,
    this.type,
    this.city,
    this.detail,
  });

  final bool isFree;
  final String? type;
  final String? city;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final labels = <String>[
      if (isFree) loc.free,
      if (type?.trim().isNotEmpty == true) type!.trim(),
      if (city?.trim().isNotEmpty == true) city!.trim(),
      if (detail?.trim().isNotEmpty == true) detail!.trim(),
    ];
    if (labels.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 5,
        runSpacing: 4,
        children: [
          for (final label in labels)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

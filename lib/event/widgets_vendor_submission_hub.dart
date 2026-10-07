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
    this.showSubmissionFilter = true,
  });

  final String submitLabel;
  final bool showOnlyMySubmissions;
  final VoidCallback onSubmit;
  final ValueChanged<bool> onFilterChanged;
  final bool showSubmissionFilter;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    const minimumActionSize = Size(72, 48);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: submitLabel,
            child: FilledButton.tonal(
              onPressed: onSubmit,
              style: FilledButton.styleFrom(
                minimumSize: minimumActionSize,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              child: Text(
                '+ ${loc.vendorSubmitShort}',
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
          if (showSubmissionFilter) ...[
            Gaps.w12,
            SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: true,
                  label: Text(
                    loc.vendorMineShort,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text(loc.vendorAllShort, maxLines: 1, softWrap: false),
                ),
              ],
              selected: {showOnlyMySubmissions},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                onFilterChanged(selection.first);
              },
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(minimumActionSize),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 16),
                ),
                textStyle: WidgetStatePropertyAll(
                  Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

bool shouldShowSubmission({
  required bool isVendor,
  required bool showOnlyMySubmissions,
  required String? submissionAccount,
  required String? currentAccount,
}) {
  if (!isVendor && !showOnlyMySubmissions) return true;
  return submissionAccount?.trim().toLowerCase() ==
      currentAccount?.trim().toLowerCase();
}

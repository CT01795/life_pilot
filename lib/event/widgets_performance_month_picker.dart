import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

Future<DateTime?> showPerformanceMonthPicker(
  BuildContext context,
  DateTime initial,
) {
  var year = initial.year;
  final loc = AppLocalizations.of(context)!;
  return showDialog<DateTime>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(loc.performanceExpiryMonth),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).previousPageTooltip,
                      onPressed: year > 1 ? () => setState(() => year--) : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        '$year',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).nextPageTooltip,
                      onPressed: year < 9998
                          ? () => setState(() => year++)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var month = 1; month <= 12; month++)
                        SizedBox(
                          width: (constraints.maxWidth - 16) / 3,
                          child: TextButton(
                            onPressed: () =>
                                Navigator.pop(context, DateTime(year, month)),
                            child: Text(
                              DateFormat.MMM(
                                loc.localeName,
                              ).format(DateTime(year, month)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
        ],
      ),
    ),
  );
}

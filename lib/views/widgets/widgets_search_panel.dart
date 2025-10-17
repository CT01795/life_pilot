import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/widget/utils_event_widgets.dart';

Widget widgetsSearchPanel({
  required TextEditingController searchController,
  required String searchKeywords,
  required void Function(String) onSearchKeywordsChanged,
  required void Function(void Function()) setState,
  DateTime? startDate,
  DateTime? endDate,
  void Function(DateTime?)? onStartDateChanged,
  void Function(DateTime?)? onEndDateChanged,
  required String tableName,
  required AppLocalizations loc,
}) {
  return Padding(
    padding: kGapEI12,
    child: Column(
      children: [
        TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: loc.search_keywords,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchKeywords.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: loc.clear,
                    onPressed: () {
                      setState(() {
                        onSearchKeywordsChanged(constEmpty);
                        searchController.clear();
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (value) {
            setState(() {
              onSearchKeywordsChanged(value.trim());
            });
          },
        ),
        if (tableName != constTableRecommendedAttractions &&
            onStartDateChanged != null &&
            onEndDateChanged != null) ...[
          kGapH8(),
          Row(
            children: [
              Expanded(
                child: widgetBuildDateButton(
                  date: startDate,
                  label: loc.start_date,
                  icon: Icons.date_range,
                  onDateChanged: onStartDateChanged,
                  loc: loc,
                ),
              ),
              kGapW16(),
              Expanded(
                child: widgetBuildDateButton(
                  date: endDate,
                  label: loc.end_date,
                  icon: Icons.date_range,
                  onDateChanged: onEndDateChanged,
                  loc: loc,
                ),
              ),
            ],
          ),
        ]
      ],
    ),
  );
}

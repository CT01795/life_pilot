import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/calendar/model_event_calendar.dart';
import 'package:life_pilot/controllers/event/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/views/widgets/event/widgets_date_button.dart';

Widget widgetsSearchPanel({
  required ModelEventCalendar modelEventCalendar,
  required ControllerEvent controllerEvent,
  required String tableName,
  required AppLocalizations loc,
  required BuildContext context,
}) {
  final filter = modelEventCalendar.searchFilter;
  return Padding(
    padding: Insets.all12,
    child: Column(
      children: [
        TextField(
          controller: modelEventCalendar.searchController,
          decoration: InputDecoration(
            hintText: loc.searchKeywords,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: filter.keywords.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: loc.clear,
                    onPressed: controllerEvent.clearSearchFilters, 
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (value) => controllerEvent.updateSearch(keywords: value.trim()),
        ),
        if (controllerEvent.showDate()) ...[
          Gaps.h8,
          Row(
            children: [
              Expanded(
                child: widgetsDateButton(
                  context: context,
                  date: filter.startDate,
                  label: loc.startDate,
                  icon: Icons.date_range,
                  onDateChanged: (value) => controllerEvent.updateSearch(startDate: value), 
                  loc: loc,
                ),
              ),
              Gaps.w16,
              Expanded(
                child: widgetsDateButton(
                  context: context,
                  date: filter.endDate,
                  label: loc.endDate,
                  icon: Icons.date_range,
                  onDateChanged: (value) => controllerEvent.updateSearch(endDate: value), 
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

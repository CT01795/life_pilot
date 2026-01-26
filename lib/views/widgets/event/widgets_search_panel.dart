import 'package:flutter/material.dart';
import 'package:life_pilot/models/event/model_event_calendar.dart';
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
            suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                tooltip: loc.clear,
                onPressed: () {
                  controllerEvent.updateKeywords(null);
                },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (value) => controllerEvent.updateKeywords(value.trim()),
        ),
        if (filter.tags.isNotEmpty) ...[
          Gaps.h8,
          Align(
            alignment: Alignment.topLeft, // 整個 Wrap 靠左上對齊
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filter.tags.map((tag) {
                return Chip(
                  label: Text(tag),
                );
              }).toList(),
            ),
          ),
        ],
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
                  onDateChanged: (value) => controllerEvent.updateStartDate(value), 
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
                  onDateChanged: (value) => controllerEvent.updateEndDate(value), 
                  loc: loc,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

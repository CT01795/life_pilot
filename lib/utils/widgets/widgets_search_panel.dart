import 'package:flutter/material.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/widgets/widgets_date_button.dart';

Widget widgetsSearchPanel({
  required ControllerEvent controllerEvent,
  required AppLocalizations loc,
  required BuildContext context,
}) {
  final filter = controllerEvent.modelEvent.searchFilter;
  return Padding(
    padding: Insets.all12,
    child: Column(
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controllerEvent.searchController,
          builder: (context, value, _) => TextField(
            controller: controllerEvent.searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: loc.searchKeywords,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: loc.clear,
                      onPressed: () => controllerEvent.updateKeywords(null),
                    ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (text) =>
                controllerEvent.updateKeywordsDebounced(text.trim()),
            onSubmitted: (text) => controllerEvent.updateKeywords(text.trim()),
          ),
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
                  onDeleted: () => controllerEvent.removeKeywordTag(tag),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  deleteButtonTooltipMessage: loc.clear,
                );
              }).toList(),
            ),
          ),
        ],
        if (controllerEvent.showDate()) ...[
          Gaps.h8,
          LayoutBuilder(
            builder: (context, constraints) {
              final startDate = widgetsDateButton(
                context: context,
                date: filter.startDate,
                label: loc.startDate,
                icon: Icons.date_range,
                onDateChanged: controllerEvent.updateStartDate,
                loc: loc,
              );
              final endDate = widgetsDateButton(
                context: context,
                date: filter.endDate,
                label: loc.endDate,
                icon: Icons.date_range,
                onDateChanged: controllerEvent.updateEndDate,
                loc: loc,
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  children: [startDate, Gaps.h8, endDate],
                );
              }
              return Row(
                children: [
                  Expanded(child: startDate),
                  Gaps.w16,
                  Expanded(child: endDate),
                ],
              );
            },
          ),
        ],
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/generic/generic_event_page.dart';
import 'package:life_pilot/utils/utils_event_app_bar_action.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:provider/provider.dart';

class PageRecommendedAttractions extends StatelessWidget {
  const PageRecommendedAttractions({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Provider<String>.value(
      value: constTableRecommendedAttractions, // 注入 tableName
      child: GenericEventPage(
        title: loc.recommended_attractions,
        tableName: constTableRecommendedAttractions,
        toTableName: constTableCalendarEvents,
        emptyText: loc.recommended_attractions_zero,
        searchPanelBuilder: buildSearchPanel,
        listBuilder: (events, controller, refreshCallback, selected, removed, setState,) {
          return EventList(
            events: events,
            selectedEventIds: selected,
            removedEventIds: removed,
            scrollController: controller,
            refreshCallback: refreshCallback,
            setState: setState,
            tableName: constTableRecommendedAttractions,
            toTableName: constTableCalendarEvents,
          );
        },
      ),
    );
  }
}

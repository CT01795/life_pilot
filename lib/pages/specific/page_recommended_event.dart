import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/generic/generic_event_page.dart';
import 'package:life_pilot/utils/utils_event_app_bar_action.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:provider/provider.dart';

class PageRecommendedEvent extends StatelessWidget {
  const PageRecommendedEvent({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Provider<String>.value(
      value: constTableRecommendedEvents, // 注入 tableName
      child: GenericEventPage(
        title: loc.recommended_event,
        tableName: constTableRecommendedEvents,
        toTableName: constTableCalendarEvents,
        emptyText: loc.recommended_event_zero,
        searchPanelBuilder: buildSearchPanel,
        listBuilder: (events, controller, refreshCallback, selected, removed, setState,) {
          return EventList(
            events: events,
            selectedEventIds: selected,
            removedEventIds: removed,
            scrollController: controller,
            refreshCallback: refreshCallback,
            setState: setState,
            tableName: constTableRecommendedEvents,
            toTableName: constTableCalendarEvents,
          );
        },
      ),
    );
  }
}

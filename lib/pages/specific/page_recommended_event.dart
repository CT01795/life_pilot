import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/pages/generic/generic_event_page.dart';
import 'package:life_pilot/utils/utils_event_app_bar_action.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:provider/provider.dart';

class PageRecommendedEvent extends StatelessWidget {
  const PageRecommendedEvent({super.key});

  static const String _tableName = constTableRecommendedEvents;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Provider<String>.value(
      value: _tableName, // 注入 tableName
      child: GenericEventPage(
        title: loc.recommended_event,
        tableName: _tableName,
        toTableName: constTableCalendarEvents,
        emptyText: loc.recommended_event_zero,
        searchPanelBuilder: buildSearchPanel,
        listBuilder: ({
          required List<Event> filteredEvents,
          required ScrollController scrollController,
          required VoidCallback refreshCallback,
          required Set<String> selectedEventIds,
          required Set<String> removedEventIds,
          required void Function(void Function()) setState,
        }) {
          return EventList(
            tableName: _tableName,
            toTableName: constTableCalendarEvents,
            filteredEvents: filteredEvents,
            selectedEventIds: selectedEventIds,
            removedEventIds: removedEventIds,
            scrollController: scrollController,
            refreshCallback: refreshCallback,
            setState: setState,
          );
        },
      ),
    );
  }
}

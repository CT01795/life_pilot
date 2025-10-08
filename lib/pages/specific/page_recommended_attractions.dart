import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_generic_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/pages/generic/generic_event_page.dart';
import 'package:life_pilot/utils/utils_event_app_bar_action.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:provider/provider.dart';

class PageRecommendedAttractions extends StatelessWidget {
  const PageRecommendedAttractions({super.key});

  static const String _tableName = constTableRecommendedAttractions;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return ChangeNotifierProvider(
      create: (_) => ControllerGenericEvent(
        tableName: _tableName,
        toTableName: constTableCalendarEvents, // 如果沒有轉移 table，也可以直接設 constEmpty
      )..loadEvents(), // 初始化後就載入資料
      child: GenericEventPage(
        title: loc.recommended_attractions,
        tableName: _tableName,
        toTableName: constTableCalendarEvents,
        emptyText: loc.recommended_attractions_zero,
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

import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/generic/generic_event_page.dart';
import 'package:life_pilot/utils/utils_event_app_bar_action.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:provider/provider.dart';

class PageMemoryTrace extends StatelessWidget {
  const PageMemoryTrace({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final tableName = constTableMemoryTrace;

    return Provider<String>.value(
      value: constTableMemoryTrace, // 注入 tableName
      child: GenericEventPage(
        title: loc.memory_trace,
        tableName: constTableMemoryTrace,
        emptyText: loc.memory_trace_zero,
        searchPanelBuilder: buildSearchPanel,
        listBuilder: (
          events,
          controller,
          refreshCallback,
          selected,
          removed,
          setState,
        ) {
          return EventList(
            tableName: tableName,
            toTableName: constEmpty,
            events: events,
            selectedEventIds: selected,
            removedEventIds: removed,
            scrollController: controller,
            refreshCallback: refreshCallback,
            setState: setState,
          );
        },
      ),
    );
  }
}

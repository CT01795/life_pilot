import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event_item.dart';
import 'package:life_pilot/pages/specific/page_base_event.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:provider/provider.dart';

import '../../views/widgets/widgets_event_list.dart';
import '../../views/widgets/widgets_search_panel.dart';

class PageMemoryTrace extends StatelessWidget {
  const PageMemoryTrace({super.key});

  static const String _tableName = constTableMemoryTrace;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return ChangeNotifierProvider(
        create: (_) => ControllerEvent(
              tableName: _tableName,
              toTableName: constEmpty, // 如果沒有轉移 table，也可以直接設 constEmpty
            )..loadEvents(), // 初始化後就載入資料
        builder: (context, _) {
          return GenericEventPage(
            title: loc.memory_trace,
            tableName: _tableName,
            emptyText: loc.memory_trace_zero,
            searchPanelBuilder: widgetsSearchPanel,
            listBuilder: ({
              required List<EventItem> filteredEvents,
              required ScrollController scrollController,
              required VoidCallback refreshCallback,
              required Set<String> selectedEventIds,
              required Set<String> removedEventIds,
              required void Function(void Function()) setState,
            }) {
              final controllerEvent = context
                  .read<ControllerEvent>(); // 取得 Provider 中的 ControllerEvent
              return WidgetsEventList(
                tableName: _tableName,
                toTableName: constEmpty,
                filteredEvents: filteredEvents,
                selectedEventIds: selectedEventIds,
                removedEventIds: removedEventIds,
                scrollController: scrollController,
                refreshCallback: refreshCallback,
                setState: setState,
                controllerEvent: controllerEvent,
              );
            },
          );
        });
  }
}

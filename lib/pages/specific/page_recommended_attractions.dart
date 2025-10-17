import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event_item.dart';
import 'package:life_pilot/pages/specific/page_base_event.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:provider/provider.dart';

import '../../views/widgets/widgets_event_list.dart';
import '../../views/widgets/widgets_search_panel.dart';

class PageRecommendedAttractions extends StatelessWidget {
  const PageRecommendedAttractions({super.key});

  static const String _tableName = constTableRecommendedAttractions;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return ChangeNotifierProvider(
        create: (_) => ControllerEvent(
              tableName: _tableName,
              toTableName:
                  constTableCalendarEvents, // 如果沒有轉移 table，也可以直接設 constEmpty
            )..loadEvents(), // 初始化後就載入資料
        // ✅ 用 builder 確保 context 在 Provider scope 裡
        builder: (context, _) {
          return GenericEventPage(
            title: loc.recommended_attractions,
            tableName: _tableName,
            toTableName: constTableCalendarEvents,
            emptyText: loc.recommended_attractions_zero,
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
                  toTableName: constTableCalendarEvents,
                  filteredEvents: filteredEvents,
                  selectedEventIds: selectedEventIds,
                  removedEventIds: removedEventIds,
                  scrollController: scrollController,
                  refreshCallback: refreshCallback,
                  setState: setState,
                  controllerEvent: controllerEvent);
            },
          );
        });
  }
}

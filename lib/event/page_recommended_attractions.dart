import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/model_event_calendar.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/page_base_event.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/service/service_weather.dart';
import 'package:life_pilot/utils/widgets/widgets_search_panel.dart';
import 'package:provider/provider.dart';

import 'widgets_event_list.dart';

class PageRecommendedAttractions extends StatefulWidget {
  const PageRecommendedAttractions({super.key});

  @override
  State<PageRecommendedAttractions> createState() =>
      _PageRecommendedAttractionsState();
}

class _PageRecommendedAttractionsState
    extends State<PageRecommendedAttractions> {
  late final ControllerEvent _controllerEvent;

  @override
  void initState() {
    super.initState();
    final context = this.context; // ✅ 避免多次 lookup
    _controllerEvent = ControllerEvent(
      auth: context.read<ControllerAuth>(),
      serviceEvent: context.read<ServiceEvent>(),
      serviceWeather: context.read<ServiceWeather>(),
      tableName: TableNames.recommendedAttractions,
      toTableName: TableNames.calendarEvents,
      modelEventCalendar: ModelEventCalendar(),
    );
  }

  @override
  void dispose() {
    _controllerEvent.dispose(); // ✅ 確保釋放資源
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final auth = context.read<ControllerAuth>();
    // ✅ 回傳 Provider Scope，包住整個頁面
    return ChangeNotifierProvider.value(
        value: _controllerEvent,
        child: GenericEventPage(
          auth: auth,
          controllerEvent: _controllerEvent,
          title: loc.recommendedAttractions,
          emptyText: loc.recommendedAttractionsZero,
          searchPanelBuilder: widgetsSearchPanel,
          listBuilder: ({
            required List<EventItem> filteredEvents,
            required ScrollController scrollController,
          }) {
            return WidgetsEventList(
                filteredEvents: filteredEvents,
                scrollController: scrollController,
                controllerEvent: _controllerEvent,
                auth: auth);
          },
        ));
  }
}

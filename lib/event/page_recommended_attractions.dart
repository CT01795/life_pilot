import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/model_event_calendar.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/page_base_event.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/service/service_weather.dart';
import 'package:life_pilot/utils/widgets/widgets_search_panel.dart';
import 'package:provider/provider.dart';

import 'widgets_event_list.dart';

class PageRecommendedAttractions extends StatefulWidget {
  const PageRecommendedAttractions({super.key});

  static const String _tableName = TableNames.recommendedAttractions;
  static const String _toTableName = TableNames.calendarEvents;

  @override
  State<PageRecommendedAttractions> createState() =>
      _PageRecommendedAttractionsState();
}

class _PageRecommendedAttractionsState
    extends State<PageRecommendedAttractions> {
  late final ControllerEvent _controllerEvent;
  late final ModelEventCalendar _modelEventCalendar;

  @override
  void initState() {
    super.initState();
    final context = this.context; // ✅ 避免多次 lookup
    _modelEventCalendar = ModelEventCalendar();
    _controllerEvent = ControllerEvent(
      auth: context.read<ControllerAuth>(),
      serviceEvent: context.read<ServiceEvent>(),
      serviceWeather: context.read<ServiceWeather>(),
      tableName: PageRecommendedAttractions._tableName,
      toTableName: PageRecommendedAttractions._toTableName,
      modelEventCalendar: _modelEventCalendar,
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
    return ChangeNotifierProvider<ControllerEvent>(
      create: (_) => _controllerEvent,
      child:GenericEventPage(
          auth: auth,
          controllerEvent: _controllerEvent,
          modelEventCalendar: _modelEventCalendar,
          title: loc.recommendedAttractions,
          tableName: PageRecommendedAttractions._tableName,
          toTableName: PageRecommendedAttractions._toTableName,
          emptyText: loc.recommendedAttractionsZero,
          searchPanelBuilder: widgetsSearchPanel,
          listBuilder: ({
            required List<EventItem> filteredEvents,
            required ScrollController scrollController,
          }) {
            return WidgetsEventList(
                tableName: PageRecommendedAttractions._tableName,
                toTableName: PageRecommendedAttractions._toTableName,
                filteredEvents: filteredEvents,
                scrollController: scrollController,
                controllerEvent: _controllerEvent,
                modelEventCalendar: _modelEventCalendar,
                auth: auth);
          },
        ));
  }
}

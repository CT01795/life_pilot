import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/calendar/controller_calendar.dart';
import 'package:life_pilot/controllers/calendar/controller_notification.dart';
import 'package:life_pilot/models/event/model_event_calendar.dart';
import 'package:life_pilot/controllers/event/controller_event.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/pages/event/page_base_event.dart';
import 'package:life_pilot/services/event/service_event.dart';
import 'package:life_pilot/services/event/service_event_public.dart';
import 'package:life_pilot/services/export/service_export_excel.dart';
import 'package:life_pilot/services/export/service_export_platform.dart';
import 'package:life_pilot/services/service_permission.dart';
import 'package:provider/provider.dart';

import '../../views/widgets/event/widgets_event_list.dart';
import '../../views/widgets/event/widgets_search_panel.dart';

class PageRecommendedEvent extends StatefulWidget {
  const PageRecommendedEvent({super.key});

  static const String _tableName = TableNames.recommendedEvents;
  static const String _toTableName = TableNames.calendarEvents;

  @override
  State<PageRecommendedEvent> createState() => _PageRecommendedEventState();
}

class _PageRecommendedEventState extends State<PageRecommendedEvent> {
  late final ControllerEvent _controllerEvent;
  late final ModelEventCalendar _modelEventCalendar;

  @override
  Future<void> initState() async {
    super.initState();
    final context = this.context; // ✅ 避免多次 lookup
    final auth = context.read<ControllerAuth>();
    final serviceEvent = context.read<ServiceEvent>();
    final controllerNotification = context.read<ControllerNotification>();

    _modelEventCalendar = ModelEventCalendar();

    _controllerEvent = ControllerEvent(
      auth: auth,
      serviceEvent: serviceEvent,
      servicePermission: ServicePermission(),
      tableName: PageRecommendedEvent._tableName,
      toTableName: PageRecommendedEvent._toTableName,
      modelEventCalendar: _modelEventCalendar,
      controllerNotification: controllerNotification,
    );
    //ServiceEventPublic().fetchAndSaveAllEventsStrolltimes(); //TODO
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
    final serviceEvent = context.read<ServiceEvent>();
    final calendar = context.read<ControllerCalendar>();
    final exportService = context.read<ServiceExportPlatform>();
    final excelService = context.read<ServiceExportExcel>();
    // ✅ 回傳 Provider Scope，包住整個頁面
    return ChangeNotifierProvider.value(
      value: _controllerEvent,
      child: GenericEventPage(
          auth: auth,
          serviceEvent: serviceEvent,
          controllerEvent: _controllerEvent,
          modelEventCalendar: _modelEventCalendar,
          exportService: exportService,
          excelService: excelService,
          title: loc.recommendedEvent,
          tableName: PageRecommendedEvent._tableName,
          toTableName: PageRecommendedEvent._toTableName,
          emptyText: loc.recommendedEventZero,
          searchPanelBuilder: widgetsSearchPanel,
          listBuilder: ({
            required List<EventItem> filteredEvents,
            required ScrollController scrollController,
          }) {
            return WidgetsEventList(
                serviceEvent: serviceEvent,
                controllerCalendar: calendar,
                tableName: PageRecommendedEvent._tableName,
                toTableName: PageRecommendedEvent._toTableName,
                filteredEvents: filteredEvents,
                scrollController: scrollController,
                controllerEvent: _controllerEvent,
                modelEventCalendar: _modelEventCalendar,
                auth: auth);
          },
        ));
  }
}

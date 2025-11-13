import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/calendar/controller_calendar.dart';
import 'package:life_pilot/controllers/calendar/controller_notification.dart';
import 'package:life_pilot/controllers/calendar/model_event_calendar.dart';
import 'package:life_pilot/controllers/event/controller_event.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/pages/event/page_base_event.dart';
import 'package:life_pilot/services/event/service_event.dart';
import 'package:life_pilot/services/export/service_export_excel.dart';
import 'package:life_pilot/services/export/service_export_platform.dart';
import 'package:life_pilot/services/service_permission.dart';
import 'package:provider/provider.dart';

import '../../views/widgets/event/widgets_event_list.dart';
import '../../views/widgets/event/widgets_search_panel.dart';

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
    final auth = context.read<ControllerAuth>();
    final serviceEvent = context.read<ServiceEvent>();
    final controllerNotification = context.read<ControllerNotification>();

    _modelEventCalendar = ModelEventCalendar();

    _controllerEvent = ControllerEvent(
      auth: auth,
      serviceEvent: serviceEvent,
      servicePermission: ServicePermission(),
      tableName: PageRecommendedAttractions._tableName,
      toTableName: PageRecommendedAttractions._toTableName,
      modelEventCalendar: _modelEventCalendar,
      controllerNotification: controllerNotification,
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
                serviceEvent: serviceEvent,
                controllerCalendar: calendar,
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

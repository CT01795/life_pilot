import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/accounting/controller_accounting_account.dart';
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
import 'package:life_pilot/services/export/service_export_excel.dart';
import 'package:life_pilot/services/export/service_export_platform.dart';
import 'package:life_pilot/services/service_permission.dart';
import 'package:provider/provider.dart';

import '../../views/widgets/event/widgets_event_list.dart';
import '../../views/widgets/event/widgets_search_panel.dart';

class PageMemoryTrace extends StatefulWidget {
  const PageMemoryTrace({super.key});

  static const String _tableName = TableNames.memoryTrace;
  static const String _toTableName = constEmpty;

 @override
  State<PageMemoryTrace> createState() => _PageMemoryTraceState();
}

class _PageMemoryTraceState extends State<PageMemoryTrace> {
  late final ControllerEvent _controllerEvent;
  late final ModelEventCalendar _modelEventCalendar;
  late final ControllerAccountingAccount _accountController;
  bool _accountsLoaded = false;

  @override
  void initState() {
    super.initState();
    final context = this.context; // ✅ 避免多次 lookup
    final auth = context.read<ControllerAuth>();
    final serviceEvent = context.read<ServiceEvent>();
    final controllerNotification = context.read<ControllerNotification>();
    _accountController = context.read<ControllerAccountingAccount>();

    _modelEventCalendar = ModelEventCalendar();

    _controllerEvent = ControllerEvent(
      auth: auth,
      serviceEvent: serviceEvent,
      servicePermission: ServicePermission(),
      tableName: PageMemoryTrace._tableName,
      toTableName: PageMemoryTrace._toTableName,
      modelEventCalendar: _modelEventCalendar,
      controllerNotification: controllerNotification,
    );
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    if(_accountController.accounts.isNotEmpty){
      setState(() {
        _accountsLoaded = true;
      });
    }
    else if (!_accountsLoaded) {
      await _accountController.loadAccounts(force: true, inputCategory: 'project');
      setState(() {
        _accountsLoaded = true;
      });
    }
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
    // 如果帳戶還沒載入，先顯示 loading
    if (!_accountsLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    // ✅ 這裡不會因為語言切換而重建 ControllerEvent
    // ✅ 但 build() 會重跑，因此 loc 會更新、文字立即刷新
    return ChangeNotifierProvider.value(
      value: _controllerEvent,
      child: GenericEventPage(
        auth: auth,
        serviceEvent: serviceEvent,
        controllerEvent: _controllerEvent,
        modelEventCalendar: _modelEventCalendar,
        exportService: exportService,
        excelService: excelService,
        title: loc.memoryTrace,
        tableName: PageMemoryTrace._tableName,
        toTableName: PageMemoryTrace._toTableName,
        emptyText: loc.memoryTraceZero,
        searchPanelBuilder: widgetsSearchPanel,
        listBuilder: ({
          required List<EventItem> filteredEvents,
          required ScrollController scrollController,
        }) {
          return WidgetsEventList(
              serviceEvent: serviceEvent,
              controllerCalendar: calendar,
              tableName: PageMemoryTrace._tableName,
              toTableName: PageMemoryTrace._toTableName,
              filteredEvents: filteredEvents,
              scrollController: scrollController,
              controllerEvent: _controllerEvent,
              modelEventCalendar: _modelEventCalendar,
              auth: auth);
        },
      ),
    );
  }
}

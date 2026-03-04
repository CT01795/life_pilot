import 'package:flutter/material.dart';
import 'package:life_pilot/accounting/controller_accounting_list.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/model_event_calendar.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/memory_trace/page_memory_base_event.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/service/service_weather.dart';
import 'package:provider/provider.dart';

import 'widgets_memory_list.dart';
import '../utils/widgets/widgets_search_panel.dart';

class PageMemoryTrace extends StatefulWidget {
  const PageMemoryTrace({super.key});

 @override
  State<PageMemoryTrace> createState() => _PageMemoryTraceState();
}

class _PageMemoryTraceState extends State<PageMemoryTrace> {
  late final ControllerEvent _controllerEvent;
  late final ModelEventCalendar _modelEventCalendar;
  late final ControllerAccountingList _accountController;
  bool _accountsLoaded = false;

  @override
  void initState() {
    super.initState();
    final context = this.context; // ✅ 避免多次 lookup
    _accountController = context.read<ControllerAccountingList>();

    _modelEventCalendar = ModelEventCalendar();

    _controllerEvent = ControllerEvent(
      auth: context.read<ControllerAuth>(),
      serviceEvent: context.read<ServiceEvent>(),
      serviceWeather: context.read<ServiceWeather>(),
      tableName: TableNames.memoryTrace,
      toTableName: '',
      modelEventCalendar: _modelEventCalendar,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadAccounts();
      }
    });

  }

  Future<void> _loadAccounts() async {
    if(_accountController.accounts.isNotEmpty){
      setState(() {
        _accountsLoaded = true;
      });
    }
    else if (!_accountsLoaded) {
      await _accountController.loadAccounts(inputCategory: 'project');
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
    // 如果帳戶還沒載入，先顯示 loading
    if (!_accountsLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    // ✅ 這裡不會因為語言切換而重建 ControllerEvent
    // ✅ 但 build() 會重跑，因此 loc 會更新、文字立即刷新
    return ChangeNotifierProvider<ControllerEvent>(
      create: (_) => _controllerEvent,
      child:MemoryGenericEventPage(
        auth: auth,
        controllerEvent: _controllerEvent,
        modelEventCalendar: _modelEventCalendar,
        title: loc.memoryTrace,
        emptyText: loc.memoryTraceZero,
        searchPanelBuilder: widgetsSearchPanel,
        listBuilder: ({
          required List<EventItem> filteredEvents,
          required ScrollController scrollController,
        }) {
          return WidgetsMemoryList(
              filteredEvents: filteredEvents,
              scrollController: scrollController,
              controllerEvent: _controllerEvent,
              auth: auth);
        },
      ),
    );
  }
}

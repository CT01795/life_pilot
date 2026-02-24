import 'dart:async';
import 'package:flutter/material.dart' hide DateUtils;
import 'package:intl/intl.dart';
import 'package:life_pilot/config/config_app.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/calendar/controller_calendar.dart';
import 'package:life_pilot/controllers/event/controller_event.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/event/model_event_calendar.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/pages/calendar/page_calendar_add.dart';
import 'package:life_pilot/services/event/service_event.dart';
import 'package:life_pilot/views/widgets/calendar/widgets_calendar.dart';
import 'package:life_pilot/core/date_time.dart';
import 'package:provider/provider.dart';

class PageCalendar extends StatefulWidget {
  const PageCalendar({
    super.key,
  });

  @override
  State<PageCalendar> createState() => _PageCalendarState();
}

class _PageCalendarState extends State<PageCalendar> {
  late final ControllerCalendar controller;
  late final ControllerEvent controllerEvent;
  late final PageController pageController;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialized) return; // 避免重複初始化
    controller = context.read<ControllerCalendar>();
    controllerEvent = ControllerEvent(
      auth: context.read<ControllerAuth>(),
      serviceEvent: context.read<ServiceEvent>(),
      modelEventCalendar: context.read<ModelEventCalendar>(),
      tableName: TableNames.calendarEvents, //TableNames.calendarEvents,
      toTableName: TableNames.memoryTrace, //TableNames.memoryTrace,
      onCalendarReload: () async {
        await controller.reloadEvents(notify: true);
      },
    );
    
    pageController = PageController(initialPage: controller.pageIndex);
    _isInitialized = true;
    // ⚡ async load，不阻塞 build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await controller.init();
      await controller.showTodayNotifications();
    });
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<ControllerAuth>();
    final serviceEvent = context.read<ServiceEvent>();
    final locale = Localizations.localeOf(context);
    return Scaffold(
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final month = controller.currentMonth;
          final isCurrentMonth = DateTimeCompare.isCurrentMonth(month);
          return Column(children: [
            // 🔹 AppBar 只關注 month 與語言，不重建 CalendarBody
            Builder(builder: (context) {
              final monthLabel = locale.languageCode == Locales.zh
                  ? DateFormat('y/M').format(month)
                  : DateFormat.yM(locale.toString()).format(month);
              return CalendarAppBar(
                monthLabel: monthLabel, //DateFormat('y / M').format(month),
                monthColor: isCurrentMonth ? Colors.blueAccent : Colors.black,
                buttonSize: MediaQuery.of(context).size.shortestSide * 0.1,
                onPrevious: () async {
                  await controller.previousMonth();
                  _updatePageController(controller.pageIndex);
                },
                onNext: () async {
                  await controller.nextMonth();
                  _updatePageController(controller.pageIndex);
                },
                onToday: () async {
                  await controller.goToToday();
                  _updatePageController(controller.pageIndex);
                },
                onAdd: () async {
                  final currentMonth = controller.currentMonth;
                  final tableName = controller.tableName;
                  final now = DateTime.now();

                  // Navigator 與 UI 都在 View 處理
                  final newEvent = await Navigator.push<EventItem?>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PageCalendarAdd(
                        auth: auth,
                        serviceEvent: serviceEvent,
                        controllerCalendar: controller,
                        existingEvent: null,
                        tableName: tableName,
                        initialDate: currentMonth.month == now.month
                            ? now
                            : currentMonth,
                      ),
                    ),
                  );

                  if (newEvent != null) {
                    // 把業務邏輯交給 Controller
                    await controller.addEvent(newEvent);
                    _updatePageController(controller.pageIndex);
                  }
                },
                onMonthTap: () => _showMonthPicker(),
              );
            }),
            // 🔹 CalendarBody 完全不受語言切換與 AppBar rebuild 影響
            Expanded(
              child: CalendarBody(
                auth: auth,
                controllerCalendar: controller,
                controllerEvent: controllerEvent,
                serviceEvent: serviceEvent,
                pageController: pageController,
              ),
            ),
          ]);
        },
      ),
    );
  }

  Future<void> _showMonthPicker() async {
    await showMonthYearPicker(
      context: context,
      initialDate: controller.currentMonth,
      onChanged: (newDate) async {
        // 1. 更新 controller 的 currentMonth 並載入該月事件
        await controller.goToMonth(month: newDate);
        _updatePageController(controller.pageIndex);
      },
    );
  }

  void _updatePageController(int index) {
    if (pageController.hasClients && pageController.page?.round() != index) {
      //pageController.jumpToPage(index);
      pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
}

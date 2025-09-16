import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide DateUtils;
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/controller_calendar.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/pages/page_recommended_event_add.dart';
import 'package:life_pilot/notification/notification.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:life_pilot/utils/utils_widgets_calendar.dart';

class PageCalendar extends StatefulWidget {
  const PageCalendar({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _PageCalendarState createState() => _PageCalendarState();
}

class _PageCalendarState extends State<PageCalendar> {
  late final ControllerCalendar _controller;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _controller = ControllerCalendar(tableName: constTableCalendarEvents);
    _pageController = PageController(initialPage: _controller.initialPage);

    // 等下一幀再載入資料（防止 build 前操作）
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _controller.loadEvents();
      // 這裡呼叫，確保資料載入完成後發通知
      AppLocalizations loc = AppLocalizations.of(context)!;
      await _notifyTodayEvents(loc);

      // 🔥 每次啟動 app 就檢查是否需要產生下一筆事件
      await _controller.checkAndGenerateNextEvents(context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _notifyTodayEvents(AppLocalizations loc) async {
    if (kIsWeb) {
      MyCustomNotification.showTodayEventsWebNotification(loc, _controller.tableName);
    }
    else if(Platform.isAndroid){
      // 從 _controller 拿今天的事件清單
      final today = DateTime.now();
      final todayDateOnly = DateUtils.dateOnly(today);
      final todayEvents = _controller.events;

      for (final event in todayEvents) {
        final end = event.endDate ?? event.startDate;
        if (isSameDayFutureTime(event.startDate, event.startTime, today) ||
            isSameDayFutureTime(end, event.endTime, today) ||
            (event.startDate != null &&
                event.startDate!.isBefore(todayDateOnly) &&
                end != null &&
                end.isAfter(todayDateOnly))) {
          await MyCustomNotification.showImmediateNotification(loc, event);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations loc = AppLocalizations.of(context)!;
    double buttonSize = MediaQuery.of(context).size.shortestSide * 0.1;
    return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          DateTime currentMonth = _controller.currentMonth;
          String monthLabel = DateFormat('y / M').format(currentMonth);
          // 🔁 這邊移進來了，確保每次 currentMonth 變動時都會重新判斷
          bool isCurrentMonth = currentMonth.year == DateTime.now().year &&
              currentMonth.month == DateTime.now().month;
          Color monthColor = isCurrentMonth ? Colors.blueAccent : Colors.black;
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent, // 移除底色
              title: CalendarAppBar(
                monthLabel: monthLabel,
                monthColor: monthColor,
                buttonSize: buttonSize,
                loc: loc,
                onPrevious: () async {
                  await _controller.goToPreviousMonth(_pageController);
                },
                onNext: () async {
                  await _controller.goToNextMonth(_pageController);
                },
                onToday: () async {
                  await _controller.goToToday(_pageController);
                },
                onAddEvent: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PageRecommendedEventAdd(
                              existingRecommendedEvent: null,
                              tableName: _controller.tableName,
                              initialDate: _controller.currentMonth,
                            )),
                  ).then((value) async {
                    if (value != null && value is Event) {
                      // 👇 更新快取讓畫面即時刷新
                      _controller.updateCachedEvent(value, value); // 第二參數 新增/修改
                      await _controller
                          .goToMonth(DateUtils.monthOnly(value.startDate!));
                    }
                  });
                },
                onMonthTap: () async {
                  await showMonthYearPicker(
                    context: context,
                    initialDate: _controller.currentMonth,
                    onChanged: (newDate) async {
                      await _controller.goToMonth(newDate);
                    },
                  );
                },
              ),
              centerTitle: true,
            ),
            body: Stack(
              children: [
                CalendarBody(
                  controller: _controller,
                  pageController: _pageController,
                  loc: loc,
                ),
                if (_controller.isLoading)
                  Positioned.fill(
                    child: Container(
                      color: const Color.fromARGB(153, 255, 255, 255),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
              ],
            ),
          );
        });
  }
}

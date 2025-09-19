import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide DateUtils;
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/controllers/controller_calendar.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/pages/page_recommended_event_add.dart';
import 'package:life_pilot/notification/notification.dart';
import 'package:life_pilot/providers/provider_locale.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:life_pilot/utils/utils_calendar_widgets.dart';
import 'package:life_pilot/utils/utils_date_time.dart'
    show DateUtils, showMonthYearPicker, DateOnlyCompare;
import 'package:provider/provider.dart';

class PageCalendar extends StatefulWidget {
  const PageCalendar({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _PageCalendarState createState() => _PageCalendarState();
}

class _PageCalendarState extends State<PageCalendar> {
  late final ControllerCalendar _controller;
  late final PageController _pageController;
  bool _initialized = false;
  late ControllerAuth _auth;
  late ProviderLocale _providerLocale;
  AppLocalizations get _loc => AppLocalizations.of(context)!;
  
  @override
  void initState() {
    super.initState();
    _controller = ControllerCalendar(tableName: constTableCalendarEvents);
    _pageController = PageController(initialPage: _controller.initialPage);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _auth = Provider.of<ControllerAuth>(context, listen: true);
    _providerLocale = Provider.of<ProviderLocale>(context, listen: true);
    if (_initialized) return;
    _initialized = true;

    // 等下一幀再載入資料（防止 build 前操作）
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _controller.loadEvents(_auth.currentAccount, _providerLocale.locale);
      // 這裡呼叫，確保資料載入完成後發通知
      await _notifyTodayEvents(_loc, _auth.currentAccount);

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

  Future<void> _notifyTodayEvents(AppLocalizations loc, String? user) async {
    if (kIsWeb) {
      MyCustomNotification.showTodayEventsWebNotification(
          loc, _controller.tableName, user);
    } else if (Platform.isAndroid) {
      // 從 _controller 拿今天的事件清單
      final today = DateTime.now();
      final todayDateOnly = DateUtils.dateOnly(today);
      final todayEvents = _controller.events;

      for (final event in todayEvents) {
        final end = event.endDate ?? event.startDate;
        if (DateOnlyCompare.isSameDayFutureTime(
                event.startDate, event.startTime, today) ||
            DateOnlyCompare.isSameDayFutureTime(end, event.endTime, today) ||
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
                loc: _loc,
                onPrevious: () async {
                  await _controller.goToPreviousMonth(
                      _pageController, _auth.currentAccount, _providerLocale.locale);
                },
                onNext: () async {
                  await _controller.goToNextMonth(
                      _pageController, _auth.currentAccount, _providerLocale.locale);
                },
                onToday: () async {
                  await _controller.goToToday(
                      _pageController, _auth.currentAccount, _providerLocale.locale);
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
                      await _controller.goToMonth(
                          DateUtils.monthOnly(value.startDate!),
                          _auth.currentAccount, _providerLocale.locale);
                    }
                  });
                },
                onMonthTap: () async {
                  await showMonthYearPicker(
                    context: context,
                    initialDate: _controller.currentMonth,
                    onChanged: (newDate) async {
                      await _controller.goToMonth(
                          newDate, _auth.currentAccount, _providerLocale.locale);
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
                    loc: _loc),
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

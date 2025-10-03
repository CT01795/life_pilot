import 'package:flutter/material.dart' hide DateUtils;
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/controller_calendar.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/notification/core/notification_helper.dart';
import 'package:life_pilot/pages/page_event_add.dart';
import 'package:life_pilot/utils/widget/utils_calendar_widgets.dart';
import 'package:life_pilot/utils/utils_date_time.dart';

class PageCalendar extends StatefulWidget {
  const PageCalendar({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _PageCalendarState createState() => _PageCalendarState();
}

class _PageCalendarState extends State<PageCalendar> {
  ControllerCalendar get _controller => getIt<ControllerCalendar>();
  late PageController _pageController;
  late final DateFormat _monthFormat;
  bool _initialized = false;
  late AppLocalizations _loc;
  Set<String> selectedEventIds = {};
  Set<String> removedEventIds = {};

  @override
  void initState() {
    super.initState();
    _monthFormat = DateFormat('y / M');
    _pageController = PageController(initialPage: _controller.initialPage);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loc = AppLocalizations.of(context)!;
    if (!_initialized) {
      _initialized = true;
      // 等下一幀再載入資料（防止 build 前操作）
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _controller.loadCalendarEvents();
        // 這裡呼叫，確保資料載入完成後發通知
        await NotificationHelper.notifyTodayEvents(
            loc: _loc);

        // 🔥 每次啟動 app 就檢查是否需要產生下一筆事件
        await _controller.checkAndGenerateNextEvents(
            loc: _loc);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double buttonSize = MediaQuery.of(context).size.shortestSide * 0.1;
    return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          DateTime currentMonth = _controller.currentMonth;
          String monthLabel = _monthFormat.format(currentMonth);
          // 🔁 這邊移進來了，確保每次 currentMonth 變動時都會重新判斷
          bool isCurrentMonth = DateTimeCompare.isCurrentMonth(currentMonth);
          Color monthColor = isCurrentMonth ? Colors.blueAccent : Colors.black;
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent, // 移除底色
              title: CalendarAppBar(
                monthLabel: monthLabel,
                monthColor: monthColor,
                buttonSize: buttonSize,
                onPrevious: () async => await _controller.goToMonth(
                    month: DateTime(currentMonth.year, currentMonth.month - 1)),
                onNext: () async => await _controller.goToMonth(
                    month: DateTime(currentMonth.year, currentMonth.month + 1)),
                onToday: () async => await _controller.goToMonth(
                  month: DateUtils.dateOnly(DateTime.now()),
                ),
                onAddEvent: _onAddEvent,
                onMonthTap: _onMonthTap,
              ),
              centerTitle: true,
            ),
            body: Stack(
              children: [
                CalendarBody(
                    pageController: _pageController,
                    loc: _loc,
                    selectedEventIds: selectedEventIds,
                    removedEventIds: removedEventIds),
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

  void _onAddEvent() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => PageEventAdd(
                existingEvent: null,
                tableName: _controller.tableName,
                initialDate:
                    _controller.currentMonth.month == DateTime.now().month
                        ? DateTime.now()
                        : _controller.currentMonth,
              )),
    ).then((value) async {
      if (value != null && value is Event) {
        // 👇 更新快取讓畫面即時刷新
        _controller.updateCachedEvent(value); // 第二參數 新增/修改
        await _controller.goToMonth(
          month: DateUtils.monthOnly(value.startDate!),
        );
      }
    });
  }

  Future<void> _onMonthTap() async {
    await showMonthYearPicker(
      context: context,
      initialDate: _controller.currentMonth,
      onChanged: (newDate) async {
        await _controller.goToMonth(
          month: newDate,
        );
      },
    );
  }
}

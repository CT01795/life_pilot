// --- AppBar Widget ---
import 'package:flutter/material.dart' hide DateUtils;
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/controllers/controller_calendar.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:life_pilot/utils/utils_date_time.dart' show DateUtils;
import 'package:life_pilot/utils/utils_show_dialog.dart';
import 'package:provider/provider.dart';

class CalendarAppBar extends StatelessWidget {
  final String monthLabel;
  final Color monthColor;
  final double buttonSize;
  final AppLocalizations loc;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onAddEvent;
  final VoidCallback onMonthTap;

  const CalendarAppBar({
    super.key,
    required this.monthLabel,
    required this.monthColor,
    required this.buttonSize,
    required this.loc,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onAddEvent,
    required this.onMonthTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.arrow_left_rounded,
              size: buttonSize * 1.2, color: monthColor),
          tooltip: loc.previous_month,
          onPressed: onPrevious,
        ),
        IconButton(
          icon: Icon(Icons.today, size: buttonSize, color: monthColor),
          tooltip: loc.today,
          onPressed: onToday,
        ),
        GestureDetector(
          onTap: onMonthTap,
          child: Text(
            monthLabel,
            style: TextStyle(
              fontSize: buttonSize * 0.5,
              color: monthColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.arrow_right_rounded,
              size: buttonSize * 1.2, color: monthColor),
          tooltip: loc.next_month,
          onPressed: onNext,
        ),
        IconButton(
          icon: Icon(Icons.add, size: buttonSize, color: monthColor),
          tooltip: loc.add,
          onPressed: onAddEvent,
        ),
      ],
    );
  }
}

// --- Calendar Body Widget ---
class CalendarBody extends StatelessWidget {
  final ControllerCalendar controller;
  final PageController pageController;
  final AppLocalizations loc;

  const CalendarBody({
    super.key,
    required this.controller,
    required this.pageController,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    ControllerAuth auth = Provider.of<ControllerAuth>(context,listen:true);
    final displayedMonth = controller.currentMonth;

    bool isCurrentMonth = displayedMonth.year == DateTime.now().year &&
        displayedMonth.month == DateTime.now().month;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableHeight =
            constraints.maxHeight - kToolbarHeight - 15;

        return Column(
          children: [
            WeekDayHeader(loc: loc, isCurrentMonth: isCurrentMonth),
            // 顯示日曆的每一行
            SizedBox(
              height: availableHeight,
              child: GestureDetector(
                onVerticalDragEnd: (details) async {
                  if (details.primaryVelocity == null) return;
                  if (details.primaryVelocity! < 0) {
                    // 往上滑，模擬往右滑，切換到下一個月
                    await controller.goToNextMonth(pageController, auth.currentAccount);
                  } else if (details.primaryVelocity! > 0) {
                    // 往下滑，模擬往左滑，切換到上一個月
                    await controller.goToPreviousMonth(pageController, auth.currentAccount);
                  }
                },
                onHorizontalDragEnd: (details) async {
                  if (details.primaryVelocity == null) return;
                  if (details.primaryVelocity! < 0) {
                    // 向左滑 ➜ 下一個月
                    await controller.goToNextMonth(pageController, auth.currentAccount);
                  } else if (details.primaryVelocity! > 0) {
                    // 向右滑 ➜ 上一個月
                    await controller.goToPreviousMonth(pageController, auth.currentAccount);
                  }
                },
                child: PageView.builder(
                  key: PageStorageKey(controller.tableName), //'pageCalendar'
                  controller: pageController,
                  physics: const NeverScrollableScrollPhysics(), // ✅ 禁用滑動
                  onPageChanged: (index) {
                    DateTime newMonth = DateTime(
                        ControllerCalendar.baseDate.year + (index ~/ 12),
                        index % 12 + 1);
                    controller.goToMonth(newMonth, auth.currentAccount);
                  },
                  itemBuilder: (context, index) {
                    return CalendarMonthView(
                      controller: controller,
                      displayedMonth: displayedMonth,
                      loc: loc,
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class WeekDayHeader extends StatelessWidget {
  final AppLocalizations loc;
  final bool isCurrentMonth;

  const WeekDayHeader({
    super.key,
    required this.loc,
    required this.isCurrentMonth,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final labelSize =
        (screenHeight > screenWidth ? screenWidth : screenHeight) * 0.05;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (index) {
        String weekday = [
          loc.week_day_sun,
          loc.week_day_mon,
          loc.week_day_tue,
          loc.week_day_wed,
          loc.week_day_thu,
          loc.week_day_fri,
          loc.week_day_sat
        ][index];

        bool isTodayWeekDay =
            isCurrentMonth && DateTime.now().weekday == index + 1;

        return Expanded(
          child: Container(
            decoration: isTodayWeekDay
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blueAccent),
                  )
                : null,
            alignment: Alignment.center,
            child: Padding(
              padding: kGapEI8,
              child: Text(
                weekday,
                style: TextStyle(
                  fontSize: labelSize * 0.6,
                  fontWeight: FontWeight.bold,
                  color: isTodayWeekDay ? Colors.blueAccent : Colors.black,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class CalendarMonthView extends StatelessWidget {
  final ControllerCalendar controller;
  final DateTime displayedMonth;
  final AppLocalizations loc;

  const CalendarMonthView({
    super.key,
    required this.controller,
    required this.displayedMonth,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    final weeks = controller.getCalendarDays(displayedMonth);
    return Column(
      children: weeks.asMap().entries.map((entry) {
        List<DateTime> week = entry.value;

        return Expanded(
          child: WeekRow(
            week: week,
            controller: controller,
            displayedMonth: displayedMonth,
            loc: loc,
          ),
        );
      }).toList(),
    );
  }
}

class WeekRow extends StatelessWidget {
  final List<DateTime> week;
  final ControllerCalendar controller;
  final DateTime displayedMonth;
  final AppLocalizations loc;

  const WeekRow({
    super.key,
    required this.week,
    required this.controller,
    required this.displayedMonth,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    ControllerAuth auth = Provider.of<ControllerAuth>(context,listen:true);
    final screenWidth = MediaQuery.of(context).size.width;
    final cellWidth = screenWidth / 7;

    // 1. 先從 controller 取得當月所有事件，並按週、日分組過的快取資料
    final calendarWeeks = controller.getCalendarDays(displayedMonth);
    final weekIndex = calendarWeeks.indexWhere((w) => w.first == week.first);

    // 2. 取出該週每一天的事件列表，已經預先分好組
    final weekEvents =
        controller.getWeekEventRows(displayedMonth)[weekIndex] ?? [];

    return Stack(
      children: [
        Row(
          children: week.map((date) {
            bool isFromOtherMonth = date.month != displayedMonth.month;
            bool isToday = date.day == DateTime.now().day &&
                date.month == DateTime.now().month &&
                date.year == DateTime.now().year;

            return Expanded(
              child: GestureDetector(
                onTap: () async {
                  final shouldReload = await showCalendarEventsDialog(
                      context, controller, date);
                  if (shouldReload) {
                    await controller.loadEvents(auth.currentAccount); // 🔁 統一更新
                  }
                },
                child: Container(
                  margin: kGapEI0,
                  decoration: BoxDecoration(
                    color: isFromOtherMonth
                        ? Colors.grey[100]
                        : Colors.transparent,
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      isToday
                          ? Container(
                              padding: kGapEI4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.blueAccent),
                              ),
                              child: Text(
                                '${date.day}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            )
                          : Text(
                              '${date.day}',
                              style: TextStyle(
                                color: isFromOtherMonth
                                    ? Colors.grey
                                    : Colors.black,
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        // 3. 使用 controller 已計算的事件分組來畫事件條
        ...weekEvents.map((eventWithRow) {
          final event = eventWithRow.event;
          final rowIndex = eventWithRow.rowIndex;

          final start = DateUtils.dateOnly(event.startDate!);
          final end = DateUtils.dateOnly(event.endDate ?? event.startDate!);
          final weekStart = week.first;
          final weekEnd = week.last;

          final visibleStart = start.isBefore(weekStart) ? weekStart : start;
          final visibleEnd = end.isAfter(weekEnd) ? weekEnd : end;

          final startIndex = visibleStart.difference(weekStart).inDays;
          final spanDays = visibleEnd.difference(visibleStart).inDays + 1;

          return PositionedDirectional(
            top: 28 + 23.0 * rowIndex,
            start: startIndex * cellWidth,
            end: (7 - (startIndex + spanDays)) * cellWidth,
            height: 22,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) async {
                final shouldReload = await showCalendarEventsDialog(
                  context,
                  controller,
                  visibleStart,
                );
                if (shouldReload) {
                  await controller.loadEvents(auth.currentAccount);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: event.isTaiwanHoliday
                      ? Colors.redAccent
                      : (event.isHoliday
                          ? Colors.transparent
                          : Colors.lightBlue),
                  borderRadius: BorderRadiusDirectional.horizontal(
                    start: (start.isAtSameMomentAs(visibleStart)
                        ? const Radius.circular(2)
                        : Radius.zero),
                    end: (end.isAtSameMomentAs(visibleEnd)
                        ? const Radius.circular(2)
                        : Radius.zero),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 0),
                alignment: Alignment.centerLeft,
                child: Center(
                  child: Text(
                    event.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                      color: !event.isTaiwanHoliday && event.isHoliday
                          ? Colors.grey
                          : Colors.white,
                      overflow: TextOverflow.clip, //.ellipsis,
                    ),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        })
      ],
    );
  }
}

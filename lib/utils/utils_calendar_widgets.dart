// --- AppBar Widget ---
import 'package:flutter/material.dart' hide DateUtils;
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/controllers/controller_calendar.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/providers/provider_locale.dart';
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
    ControllerAuth auth = Provider.of<ControllerAuth>(context, listen: true);
    ProviderLocale providerLocale =
        Provider.of<ProviderLocale>(context, listen: true);
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
                    await controller.goToNextMonth(pageController,
                        auth.currentAccount, providerLocale.locale);
                  } else if (details.primaryVelocity! > 0) {
                    // 往下滑，模擬往左滑，切換到上一個月
                    await controller.goToPreviousMonth(pageController,
                        auth.currentAccount, providerLocale.locale);
                  }
                },
                onHorizontalDragEnd: (details) async {
                  if (details.primaryVelocity == null) return;
                  if (details.primaryVelocity! < 0) {
                    // 向左滑 ➜ 下一個月
                    await controller.goToNextMonth(pageController,
                        auth.currentAccount, providerLocale.locale);
                  } else if (details.primaryVelocity! > 0) {
                    // 向右滑 ➜ 上一個月
                    await controller.goToPreviousMonth(pageController,
                        auth.currentAccount, providerLocale.locale);
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
                    controller.goToMonth(
                        newMonth, auth.currentAccount, providerLocale.locale);
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
            weekRowKey: GlobalKey(), // ✅ 傳入一個 key（可共用或為每週新建）
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
  final GlobalKey weekRowKey; // ✅ 提升為屬性

  const WeekRow({
    super.key,
    required this.week,
    required this.controller,
    required this.displayedMonth,
    required this.loc,
    required this.weekRowKey,
  });

  @override
  Widget build(BuildContext context) {
    ControllerAuth auth = Provider.of<ControllerAuth>(context, listen: true);
    ProviderLocale providerLocale =
        Provider.of<ProviderLocale>(context, listen: true);
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
          key: weekRowKey,
          children: week.map((date) {
            bool isFromOtherMonth = date.month != displayedMonth.month;
            bool isToday = date.day == DateTime.now().day &&
                date.month == DateTime.now().month &&
                date.year == DateTime.now().year;

            return Expanded(
              child: GestureDetector(
                onTap: () async {
                  // ✅ 若點到的是不同月份，就先載入該月份資料
                  await handleCrossMonthTap(
                    context: context,
                    tappedDate: date,
                    displayedMonth: displayedMonth,
                    controller: controller,
                    auth: auth,
                    providerLocale: providerLocale,
                  );

                  final shouldReload =
                      await showCalendarEventsDialog(context, controller, date);
                  if (shouldReload) {
                    await controller.loadEvents(
                        auth.currentAccount, providerLocale.locale); // 🔁 統一更新
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
                final RenderBox? box = weekRowKey.currentContext
                    ?.findRenderObject() as RenderBox?;
                if (box == null) return;

                // 把全域點擊座標轉成在整週格子中的相對座標
                final localOffset = box.globalToLocal(details.globalPosition);
                final tapX = localOffset.dx;

                // 算出第幾格（哪一天）
                final tappedIndex = (tapX / cellWidth).floor().clamp(0, 6);
                final tappedDate = week.first.add(Duration(days: tappedIndex));

                // ✅ 若點到的是不同月份，就先載入那個月份的資料
                await handleCrossMonthTap(
                  context: context,
                  tappedDate: tappedDate,
                  displayedMonth: displayedMonth,
                  controller: controller,
                  auth: auth,
                  providerLocale: providerLocale,
                );

                // 4. 呼叫 dialog，並傳入正確的日期
                final shouldReload = await showCalendarEventsDialog(
                  context,
                  controller,
                  tappedDate,
                );

                if (shouldReload) {
                  await controller.loadEvents(
                      auth.currentAccount, providerLocale.locale);
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

Future<void> handleCrossMonthTap({
  required BuildContext context,
  required DateTime tappedDate,
  required DateTime displayedMonth,
  required ControllerCalendar controller,
  required ControllerAuth auth,
  required ProviderLocale providerLocale,
}) async {
  if (tappedDate.month != displayedMonth.month || tappedDate.year != displayedMonth.year) {
    //先確認其他月份的資料
    await controller.goToMonth(
      DateTime(tappedDate.year, tappedDate.month),
      auth.currentAccount,
      providerLocale.locale,
      notify: false,
    );
    //再回到原本的位置
    await controller.goToMonth(
      displayedMonth,
      auth.currentAccount,
      providerLocale.locale,
      notify: false,
    );
  }
}

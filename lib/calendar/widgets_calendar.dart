// --- AppBar Widget ---
import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/controller_calendar_event_card.dart';
import 'package:life_pilot/calendar/page_calendar_add.dart';
import 'package:life_pilot/calendar/widgets_calendar_events_dialog.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart'
    show DateTimeCompare, DateTimeFormatter;
import 'package:life_pilot/utils/extension.dart';
import 'package:provider/provider.dart';

class CalendarAppBar extends StatelessWidget {
  final String monthLabel;
  final Color monthColor;
  final double buttonSize;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onAdd;
  final VoidCallback onMonthTap;

  const CalendarAppBar({
    super.key,
    required this.monthLabel,
    required this.monthColor,
    required this.buttonSize,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onAdd,
    required this.onMonthTap,
  });

  @override
  Widget build(BuildContext context) {
    final double navIconSize = buttonSize * 1.2;
    AppLocalizations loc = AppLocalizations.of(context)!;

    Widget iconButton(
            IconData icon, VoidCallback onTap, String tooltip, double size) =>
        IconButton(
          icon: Icon(icon, size: navIconSize, color: monthColor),
          tooltip: tooltip,
          onPressed: onTap,
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        iconButton(Icons.arrow_left_rounded, onPrevious, loc.previousMonth,
            navIconSize),
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
        iconButton(
            Icons.arrow_right_rounded, onNext, loc.nextMonth, navIconSize),
        iconButton(Icons.add, onAdd, loc.add, buttonSize),
      ],
    );
  }
}

// --- Calendar Body Widget ---
class CalendarBody extends StatelessWidget {
  final PageController pageController;
  final ControllerCalendar controllerCalendar;
  final ControllerAuth auth;
  final ServiceEvent serviceEvent;

  const CalendarBody({
    super.key,
    required this.auth,
    required this.controllerCalendar,
    required this.pageController,
    required this.serviceEvent,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableHeight =
            constraints.maxHeight - kToolbarHeight + 2;

        return Column(
          children: [
            WeekDayHeader(
                isCurrentMonth: DateTimeCompare.isCurrentMonth(
                    controllerCalendar.currentMonth)),
            // 顯示日曆的每一行
            SizedBox(
              height: availableHeight,
              child: PageView.builder(
                controller: pageController,
                onPageChanged: (index) async {
                  final newMonth =
                      controllerCalendar.pageIndexToMonth(index: index);
                  // ✅ 不直接觸發 UI，等資料載完再一次刷新
                  //await controllerCalendar.loadCalendarEvents(month: newMonth);
                  await controllerCalendar.goToMonth(month: newMonth);
                },
                itemBuilder: (context, index) {
                  final monthToShow =
                      controllerCalendar.pageIndexToMonth(index: index);
                  return CalendarMonthView(
                    key: ValueKey(monthToShow.toMonthKey()), // ✅ 用顯示月份決定 key
                    auth: auth,
                    serviceEvent: serviceEvent,
                    controllerCalendar: controllerCalendar,
                    displayedMonth: monthToShow,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class WeekDayHeader extends StatelessWidget {
  final bool isCurrentMonth;

  const WeekDayHeader({
    super.key,
    required this.isCurrentMonth,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!; // ✅ 直接讀 context
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final labelSize =
        (screenHeight > screenWidth ? screenWidth : screenHeight) * 0.05;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (index) {
        String weekday = [
          loc.weekDaySun,
          loc.weekDayMon,
          loc.weekDayTue,
          loc.weekDayWed,
          loc.weekDayThu,
          loc.weekDayFri,
          loc.weekDaySat
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
            child: Text(
              weekday,
              style: TextStyle(
                fontSize: labelSize * 0.6,
                fontWeight: FontWeight.bold,
                color: isTodayWeekDay ? Colors.blueAccent : Colors.black,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class CalendarMonthView extends StatelessWidget {
  final ControllerCalendar controllerCalendar;
  final ControllerAuth auth;
  final ServiceEvent serviceEvent;
  final DateTime displayedMonth;

  const CalendarMonthView({
    super.key,
    required this.auth,
    required this.serviceEvent,
    required this.controllerCalendar,
    required this.displayedMonth,
  });

  @override
  Widget build(BuildContext context) {
    final weeks = controllerCalendar.getWeeks(month: displayedMonth);
    // ✅ 建立 key 映射，每週一個 GlobalKey
    final Map<String, GlobalKey> weekKeys = {
      for (var week in weeks) week.first.toIso8601String(): GlobalKey()
    };

    return Column(
      children: weeks.asMap().entries.map((entry) {
        List<DateTime> week = entry.value;

        return Expanded(
          child: WeekRow(
            auth: auth,
            serviceEvent: serviceEvent,
            controllerCalendar: controllerCalendar,
            week: week,
            displayedMonth: displayedMonth,
            weekRowKey: weekKeys[
                week.first.toIso8601String()]!, // ✅ 傳入一個 key（可共用或為每週新建）
          ),
        );
      }).toList(),
    );
  }
}

class WeekRow extends StatelessWidget {
  final ControllerCalendar controllerCalendar;
  final ControllerAuth auth;
  final ServiceEvent serviceEvent;
  final List<DateTime> week;
  final DateTime displayedMonth;
  final GlobalKey weekRowKey; // ✅ 提升為屬性
  const WeekRow({
    super.key,
    required this.controllerCalendar,
    required this.auth,
    required this.serviceEvent,
    required this.week,
    required this.displayedMonth,
    required this.weekRowKey,
  });

  Future<void> _openDayDialog(
    BuildContext context,
    DateTime date,
  ) async {
    final loc = AppLocalizations.of(context)!;
    final dateOnly = DateTimeFormatter.dateOnly(date);
    final eventsOfDay = controllerCalendar.getEventsOfDay(dateOnly);

    /// ✅ ① 如果沒有事件 → 直接跳新增頁
    if (eventsOfDay.isEmpty) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PageCalendarAdd(
            auth: auth,
            serviceEvent: serviceEvent,
            controllerCalendar: controllerCalendar,
            existingEvent: null,
            tableName: controllerCalendar.tableName,
            initialDate: date,
          ),
        ),
      );

      if (result != null && result.startDate != null && result is EventItem) {
        await controllerCalendar.loadCalendarEvents(
          month: controllerCalendar.currentMonth);
      }

      return; // 🔥 直接結束，不開 Dialog
    }

    /// ✅ ② 有事件 → 才 showDialog
    final eventCardCtrl = context.read<ControllerCalendarEventCard>();

    final shouldReload = await showDialog<bool>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: eventCardCtrl,
        child: CalendarEventsDialog(
          auth: auth,
          controllerCalendar: controllerCalendar,
          serviceEvent: serviceEvent,
          modelCalendar: controllerCalendar.modelCalendar,
          date: date,
          loc: loc,
        ),
      ),
    );

    if (shouldReload == true) {
      await controllerCalendar.loadCalendarEvents(
          month: controllerCalendar.currentMonth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cellWidth = screenWidth / 7;

    return Consumer<ControllerCalendar>(
        builder: (context, controllerCalendar, _) {
      // 1. 先從 controller 取得當月所有事件，並按週、日分組過的快取資料
      final calendarWeeks = controllerCalendar.getWeeks(month: displayedMonth);
      final weekIndex = calendarWeeks.indexWhere((w) => w.first == week.first);

      // 2. 取出該週每一天的事件列表，已經預先分好組
      final weekEvents = controllerCalendar.getWeekEventRows(
              month: displayedMonth)[weekIndex] ??
          [];
      return LayoutBuilder(builder: (context, constraints) {
        const dateCellHeight = 28.0; // 日期格子高度固定

        final eventHeight = 22.0; //eventAreaHeight / maxEventRows;
        final now = DateTime.now();
        return Stack(
          children: [
            Row(
              key: weekRowKey,
              children: week.map((date) {
                bool isFromOtherMonth = date.month != displayedMonth.month;
                bool isToday = date.day == now.day &&
                    date.month == now.month &&
                    date.year == now.year;

                return Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      // ✅ 若點到的是不同月份，就先載入該月份資料
                      await handleCrossMonthTap(
                        controllerCalendar: controllerCalendar,
                        tappedDate: date,
                        displayedMonth: displayedMonth,
                      );

                      await _openDayDialog(context, date);
                    },
                    child: Container(
                      margin: Insets.e0,
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
                                  padding: Insets.all2,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: Colors.blueAccent),
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

              final start = DateTimeFormatter.dateOnly(event.startDate!);
              final end =
                  DateTimeFormatter.dateOnly(event.endDate ?? event.startDate!);
              final weekStart = week.first;
              final weekEnd = week.last;

              final visibleStart =
                  start.isBefore(weekStart) ? weekStart : start;
              final visibleEnd = end.isAfter(weekEnd) ? weekEnd : end;

              final startIndex = visibleStart.difference(weekStart).inDays;
              final spanDays = visibleEnd.difference(visibleStart).inDays + 1;

              return PositionedDirectional(
                top: dateCellHeight +
                    eventHeight * rowIndex, // ✅ 自適應 top: 28 + 23.0 * rowIndex,
                start: startIndex * cellWidth,
                end: (7 - (startIndex + spanDays)) * cellWidth,
                height: eventHeight, //height: 22,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) async {
                    final RenderBox? box = weekRowKey.currentContext
                        ?.findRenderObject() as RenderBox?;
                    if (box == null) return;

                    // 把全域點擊座標轉成在整週格子中的相對座標
                    final localOffset =
                        box.globalToLocal(details.globalPosition);
                    final tapX = localOffset.dx;

                    // 算出第幾格（哪一天）
                    final tappedIndex = (tapX / cellWidth).floor().clamp(0, 6);
                    final tappedDate =
                        week.first.add(Duration(days: tappedIndex));

                    // ✅ 若點到的是不同月份，就先載入那個月份的資料
                    await handleCrossMonthTap(
                      controllerCalendar: controllerCalendar,
                      tappedDate: tappedDate,
                      displayedMonth: displayedMonth,
                    );

                    // 4. 呼叫 dialog，並傳入正確的日期
                    await _openDayDialog(context, tappedDate);
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
      });
    });
  }
}

Future<void> handleCrossMonthTap({
  required ControllerCalendar controllerCalendar,
  required DateTime tappedDate,
  required DateTime displayedMonth,
}) async {
  if (tappedDate.month != displayedMonth.month ||
      tappedDate.year != displayedMonth.year) {
    // 預載其他月份事件，但不改 displayedMonth
    await controllerCalendar.loadCalendarEvents(
        month: DateTime(tappedDate.year, tappedDate.month), notify: false);
    await controllerCalendar.goToMonth(month: displayedMonth, notify: true);
  }
}

import 'package:flutter/material.dart' hide DateUtils;
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/calendar/controller_calendar.dart';
import 'package:life_pilot/models/event/model_event_calendar.dart';
import 'package:life_pilot/core/app_navigator.dart';
import 'package:life_pilot/core/app_navigator.dart' as app_navigator;
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/pages/event/page_event_add.dart';
import 'package:life_pilot/services/event/service_event.dart';
import 'package:life_pilot/views/widgets/event/widgets_confirmation_dialog.dart';
import 'package:life_pilot/views/widgets/event/widgets_event_trailing.dart';
import 'package:life_pilot/views/widgets/calendar/widgets_calendar.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/date_time.dart';
import 'package:life_pilot/views/widgets/event/widgets_event_card.dart';

Future<bool> showCalendarEventsDialog({
  required ControllerAuth auth,
  required ControllerCalendar controllerCalendar,
  required ServiceEvent serviceEvent,
  required DateTime date,
  required AppLocalizations loc,
  required ModelEventCalendar modelEventCalendar,
}) async {
  final tableName = TableNames.calendarEvents;
  final dateOnly = DateUtils.dateOnly(date);
  
  //如果點到的是跨月日期，先載入那月資料 ——
  if (date.month != controllerCalendar.currentMonth.month ||
      date.year != controllerCalendar.currentMonth.year) {
    // ✅ 若點到的是不同月份，就先載入那個月份的資料
    await handleCrossMonthTap(
      controllerCalendar: controllerCalendar,
      tappedDate: date,
      displayedMonth: controllerCalendar.currentMonth,
    );
  }

  // 篩選包含該日期的事件
  final eventsOfDay = controllerCalendar.getEventsOfDay(dateOnly);

  // ✅ 如果沒有事件，直接跳轉新增事件頁
  if (eventsOfDay.isEmpty) {
    final result = await app_navigator.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => PageEventAdd(
          auth: auth,
          serviceEvent: serviceEvent,
          controllerEvent: controllerCalendar.controllerEvent,
          existingEvent: null,
          tableName: controllerCalendar.tableName,
          initialDate: date,
        ),
      ),
    );
    if (result != null && result is EventItem) {
      await controllerCalendar.goToMonth(
        month: DateUtils.monthOnly(result.startDate!),
      );
      return true;
    }
    return false;
  }

  // ✅ 有事件時，顯示 Dialog
  final result = await showDialog<bool>(
    context: app_navigator.navigatorKey.currentState!.context,
    barrierDismissible: true,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        // 每次build時都重新抓當天事件，確保資料最新
        final updatedEventsOfDay =
            controllerCalendar.getEventsOfDay(dateOnly);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: Insets.h6,
          child: Stack(
            children: [
              // 內容區塊
              SingleChildScrollView(
                child: Container(
                  padding: Insets.e0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat(DateFormats.mmdd).format(date),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add,
                                size: IconTheme.of(context).size!),
                            tooltip: loc.add,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => PageEventAdd(
                                          auth: auth,
                                          serviceEvent: serviceEvent,
                                          controllerEvent: controllerCalendar.controllerEvent,
                                          existingEvent: null,
                                          tableName:
                                              controllerCalendar.tableName,
                                          initialDate: date,
                                        )),
                              ).then((value) {
                                if (value != null && value is EventItem) {
                                  controllerCalendar.goToMonth(
                                    month:
                                        DateUtils.monthOnly(value.startDate!),
                                  );
                                  Navigator.pop(
                                      context, true); // ✅ 回傳 true 給外層
                                }
                              });
                            },
                          ),
                        ]
                      ),
                      if (updatedEventsOfDay.isNotEmpty)
                        // 如果當日有事件，顯示事件列表，沒有的話顯示提示文字
                        ...updatedEventsOfDay.map((event) {
                          return WidgetsEventCard(
                            eventViewModel: controllerCalendar.controllerEvent.buildEventViewModel(
                              event: event,
                              parentLocation: constEmpty,
                              canDelete: controllerCalendar.controllerEvent.canDelete(
                                  account: event.account ?? constEmpty),
                              showSubEvents: true,
                              loc: loc
                            ),
                            tableName: tableName,
                            onTap: () => Navigator.pop(context),
                            onDelete: event.isHoliday
                                ? null
                                : () async {
                                    final shouldDelete =
                                        await showConfirmationDialog(
                                      content:
                                          '${loc.eventDelete}「${event.name}」？',
                                      confirmText: loc.delete,
                                      cancelText: loc.cancel,
                                    );

                                    if (shouldDelete == true) {
                                      try {
                                        await controllerCalendar.controllerEvent.deleteEvent(
                                            event);
                                        AppNavigator.showSnackBar(loc.deleteOk);
                                      } catch (e) {
                                        AppNavigator.showErrorBar(
                                            '${loc.deleteError}: $e');
                                      }
                                    }
                                    Navigator.pop(
                                        context, true); // ✅ 回傳 true 給外層
                                  },
                            trailing: widgetsEventTrailing(
                              context: context,
                              auth: auth,
                              serviceEvent: serviceEvent,
                              controllerCalendar: controllerCalendar,
                              controllerEvent: controllerCalendar.controllerEvent,
                              modelEventCalendar: modelEventCalendar,
                              event: event,
                              tableName: controllerCalendar.tableName,
                              toTableName: TableNames
                                  .memoryTrace, // ✅ 如果有其他目標 table，這裡替換掉
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),

              // 右上角關閉按鈕
              PositionedDirectional(
                end: Insets.all2.right,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 4,
                        offset: Offset(0, 2),
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.close, size: IconTheme.of(context).size!),
                    tooltip: controllerCalendar.closeText,
                    onPressed: () =>
                        Navigator.pop(context, false), // ✅ 明確回傳 false
                  ),
                ),
              ),
            ],
          ),
        );
      });
    },
  );
  return result == true; // 預設 null 或 false 都視為沒變更
}

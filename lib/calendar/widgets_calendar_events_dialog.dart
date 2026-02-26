import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/accounting/controller_accounting_list.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/calendar/page_calendar_add_ok.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/calendar/widgets_calendar_card.dart';
import 'package:life_pilot/calendar/widgets_calendar_trailing.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/utils/widgets/widgets_confirmation_dialog.dart';
import 'package:life_pilot/calendar/widgets_calendar.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:provider/provider.dart';

class CalendarEventsDialog extends StatelessWidget {
  final ControllerAuth auth;
  final ControllerCalendar controllerCalendar;
  final ServiceEvent serviceEvent;
  final ModelCalendar modelCalendar;
  final DateTime date;
  final AppLocalizations loc;

  const CalendarEventsDialog({
    super.key,
    required this.auth,
    required this.controllerCalendar,
    required this.serviceEvent,
    required this.modelCalendar,
    required this.date,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    final tableName = TableNames.calendarEvents;
    final dateOnly = DateTimeFormatter.dateOnly(date);

    return StatefulBuilder(builder: (context, setState) {
      // 每次build時都重新抓當天事件，確保資料最新
      final updatedEventsOfDay = controllerCalendar.getEventsOfDay(dateOnly);

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
                            onPressed: () async {
                              final newEvent = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => PageCalendarAdd(
                                          auth: auth,
                                          serviceEvent: serviceEvent,
                                          controllerCalendar:
                                              controllerCalendar,
                                          existingEvent: null,
                                          tableName:
                                              controllerCalendar.tableName,
                                          initialDate: date,
                                        )),
                              );
                              if (newEvent != null) {
                                await handleCrossMonthTap(
                                  controllerCalendar: controllerCalendar,
                                  tappedDate: newEvent.startDate!,
                                  displayedMonth:
                                      controllerCalendar.currentMonth,
                                );
                                Navigator.pop(context, true); // ✅ 回傳 true 給外層
                              }
                            },
                          ),
                        ]),
                    if (updatedEventsOfDay.isNotEmpty)
                      // 如果當日有事件，顯示事件列表，沒有的話顯示提示文字
                      ...updatedEventsOfDay.map((event) {
                        final eventViewModel =
                            EventViewModel.buildEventViewModel(
                          event: event,
                          parentLocation: '',
                          canDelete: ControllerCalendar.canDelete(
                            account: event.account ?? '',
                            auth: auth,
                            tableName: tableName,
                          ),
                          showSubEvents: true,
                          loc: loc,
                          tableName: tableName,
                        );

                        return WidgetsCalendarCard(
                          eventViewModel: eventViewModel,
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
                                      await controllerCalendar
                                          .deleteEvent(event);
                                      AppNavigator.showSnackBar(
                                          loc.deleteOk);
                                    } catch (e) {
                                      AppNavigator.showErrorBar(
                                          '${loc.deleteError}: $e');
                                    }
                                  }
                                  Navigator.pop(
                                      context, true); // ✅ 回傳 true 給外層
                                },
                          onAccounting: () => context
                              .read<ControllerAccountingList>()
                              .handleAccounting(
                                context: context,
                                eventId: event.id,
                              ),
                          trailing: widgetsCalendarTrailing(
                            context: context,
                            auth: auth,
                            serviceEvent: serviceEvent,
                            controllerCalendar: controllerCalendar,
                            modelCalendar: modelCalendar,
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
  }
}

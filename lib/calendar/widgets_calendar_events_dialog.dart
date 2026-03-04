import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/accounting/controller_accounting_list.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/controller_calendar_ui.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/calendar/widgets_calendar_card.dart';
import 'package:life_pilot/calendar/widgets_calendar_trailing.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:provider/provider.dart';

class CalendarEventsDialog extends StatelessWidget {
  final ControllerAuth auth;
  final ControllerCalendar controllerCalendar;
  final DateTime date;
  final AppLocalizations loc;

  const CalendarEventsDialog({
    super.key,
    required this.auth,
    required this.controllerCalendar,
    required this.date,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    final tableName = TableNames.calendarEvents;
    final dateOnly = DateTimeFormatter.dateOnly(date);
    // 每次build時都重新抓當天事件，確保資料最新
    final updatedEventsOfDay = controllerCalendar.getEventsOfDay(dateOnly);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: Insets.h6,
      child: Stack(
        children: [
          // 內容區塊
          Container(
            padding: Insets.e0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: 1 + updatedEventsOfDay.length, // 1 是標題列
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // 標題列
                    return Row(
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
                                size: IconTheme.of(context).size ?? 24.0),
                            tooltip: loc.add,
                            onPressed: () => onAddEventPressed(
                                context: context,
                                controller: controllerCalendar,
                                date: date),
                          ),
                        ]);
                  }
                  final event = updatedEventsOfDay[index - 1];
                  final eventViewModel = EventViewModel.buildEventViewModel(
                    event: event,
                    parentLocation: '',
                    canDelete: controllerCalendar.canDelete(
                      account: event.account ?? '',
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
                            await onDeletePressed(
                              context: context,
                              controller: controllerCalendar,
                              event: event,
                              loc: loc,
                            );
                          },
                    onAccounting: () => context
                        .read<ControllerAccountingList>()
                        .handleAccounting(
                          context: context,
                          eventId: event.id,
                        ),
                    onOpenMap: () =>
                        controllerCalendar.onOpenMap(eventViewModel),
                    onOpenLink: () =>
                        controllerCalendar.onOpenLink(eventViewModel),
                    trailing: widgetsCalendarTrailing(
                      context: context,
                      controllerCalendar: controllerCalendar,
                      event: event,
                    ),
                  );
                }),
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
                icon:
                    Icon(Icons.close, size: IconTheme.of(context).size ?? 24.0),
                tooltip: controllerCalendar.closeText,
                onPressed: () => Navigator.pop(context, false), // ✅ 明確回傳 false
              ),
            ),
          ),
        ],
      ),
    );
  }
}

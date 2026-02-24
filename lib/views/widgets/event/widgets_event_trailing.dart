import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/calendar/controller_calendar.dart';
import 'package:life_pilot/models/event/model_event_calendar.dart';
import 'package:life_pilot/controllers/event/controller_event.dart';
import 'package:life_pilot/core/app_navigator.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/pages/event/page_event_add.dart';
import 'package:life_pilot/services/event/service_event.dart';
import 'package:life_pilot/views/widgets/core/widgets_confirmation_dialog.dart';

Widget widgetsEventTrailing({
  required BuildContext context,
  required ControllerAuth auth,
  required ServiceEvent serviceEvent,
  required ControllerEvent controllerEvent,
  required ControllerCalendar? controllerCalendar,
  required ModelEventCalendar modelEventCalendar,
  required EventItem event,
  required String tableName,
  required String toTableName,
}) {
  AppLocalizations loc = AppLocalizations.of(context)!;
  return Transform.scale(
    scale: 1.2,
    child: Row(
      mainAxisSize: MainAxisSize.min, // 避免 unbounded 爆錯
      children: [
        if (!auth.isAnonymous && tableName != TableNames.memoryTrace)
          Flexible(
            fit: FlexFit.loose,
            child: Builder(
              builder: (ctx) {
                // 確保使用正確的 BuildContext 讀取 Provider
                return Checkbox(
                  value: controllerEvent.modelEventCalendar.selectedEventIds
                      .contains(event.id),
                  onChanged: (value) async {
                    bool tmpValue = value ?? false;
                    if (!tmpValue) {
                      controllerEvent.toggleEventSelection(event.id, false);
                      return;
                    }

                    bool isAlreadyAdded =
                        await controllerEvent.handleEventCheckboxIsAlreadyAdd(
                            event, tmpValue, toTableName);
                    final shouldTransfer = await confirmEventTransfer(
                        context: context,
                        event: event,
                        controllerEvent: controllerEvent,
                        fromTableName: tableName,
                        toTableName: toTableName,
                        loc: loc,
                        isAlreadyAdded: isAlreadyAdded);
                    if (shouldTransfer ?? false) {
                      final targetEvent = await controllerEvent.handleEventCheckboxTransfer(
                        tmpValue,
                        isAlreadyAdded,
                        event,
                        toTableName,
                      );
                      await controllerCalendar?.handleEventCheckboxTransfer(
                        tmpValue,
                        isAlreadyAdded,
                        event,
                        toTableName,
                        targetEvent
                      );
                      AppNavigator.showSnackBar(loc.eventAddOk);
                    } else {
                      controllerEvent.toggleEventSelection(event.id, false);
                    }
                  },
                );
              },
            ),
          ),
        if (auth.currentAccount == event.account)
          IconButton(
              icon: const Icon(Icons.edit),
              tooltip: loc.edit,
              onPressed: () async {
                final updatedEvent =
                    await Navigator.of(context).push<EventItem?>(
                  MaterialPageRoute(
                    builder: (_) => PageEventAdd(
                      auth: auth,
                      serviceEvent: serviceEvent,
                      controllerEvent:
                          controllerEvent,
                      tableName: tableName,
                      existingEvent: event,
                    ),
                  ),
                );

                if (updatedEvent != null) {
                  await controllerEvent.onEditEvent(
                    event: event,
                    updatedEvent: updatedEvent,
                  );
                }
                // ✅ 只在確定有更新時再關閉外層對話框
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              }),
        if (tableName != TableNames.memoryTrace &&
            !event.isApproved &&
            auth.currentAccount == AuthConstants.sysAdminEmail)
          IconButton(
            icon: const Icon(Icons.task_alt),
            tooltip: loc.review,
            onPressed: () async {
              await controllerEvent.approveEvent(event: event);
            },
          ),
        Gaps.w24,
      ],
    ),
  );
}

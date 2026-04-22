import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/controller_event_ui.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:provider/provider.dart';

Widget widgetsEventTrailing({
  required BuildContext context,
  required ControllerAuth auth,
  required ControllerEvent controllerEvent,
  required EventItem event,
}) {
  AppLocalizations loc = AppLocalizations.of(context)!;
  return Transform.scale(
    scale: 1.2,
    child: Row(
      mainAxisSize: MainAxisSize.min, // 避免 unbounded 爆錯
      children: [
        if (!auth.isAnonymous && controllerEvent.fromTableName != TableNames.memoryTrace)
          Selector<ControllerEvent, bool>(
            selector: (_, c) => c.isEventSelected(event.id),
            builder: (_, isSelected, __) {
              return Tooltip(
                message: loc.eventAdd1,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (value) => onMemoryCheckboxChanged(
                    context: context, controller: controllerEvent, value: value, event: event, loc: loc),
                ));
            },
          ),
        if (auth.currentAccount == event.account)
          IconButton(
              icon: const Icon(Icons.edit),
              tooltip: loc.edit,
              onPressed: () => onEditPressed(
                context: context, controller: controllerEvent, event: event,),
              ),
        if (controllerEvent.fromTableName != TableNames.memoryTrace &&
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

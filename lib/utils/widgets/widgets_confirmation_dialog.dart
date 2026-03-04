import 'package:flutter/material.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/utils/app_navigator.dart' as app_navigator;
import 'package:life_pilot/l10n/app_localizations.dart';

Future<bool> showConfirmationDialog({
  required String content,
  required String confirmText,
  required String cancelText,
}) async {
  final navigator = app_navigator.navigatorKey.currentState;
  if (navigator == null) {
    // 沒有 navigator，直接回傳 false 或 throw
    return false;
  }

  return await showDialog<bool>(
        context: navigator.context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText, style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText, style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ) ??
      false;
}

Future<bool?> confirmCalenderEventTransfer(
      {required BuildContext context,
      required var event,
      required ControllerCalendar controller,
      required AppLocalizations loc,
      required bool isAlreadyAdded}) async {

  final content = controller.buildTransferMessage(
    isAlreadyAdded: isAlreadyAdded,
    event: event,
    loc: loc,
  );

  return showConfirmationDialog(
    content: content,
    confirmText: loc.add,
    cancelText: loc.cancel,
  );
}

Future<bool?> confirmEventTransfer(
      {required BuildContext context,
      required var event,
      required ControllerEvent controller,
      required AppLocalizations loc,
      required bool isAlreadyAdded}) async {

  final content = controller.buildTransferMessage(
    isAlreadyAdded: isAlreadyAdded,
    event: event,
    loc: loc,
  );

  return showConfirmationDialog(
    content: content,
    confirmText: loc.add,
    cancelText: loc.cancel,
  );
}

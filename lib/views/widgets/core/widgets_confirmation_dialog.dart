import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/event/controller_event.dart';
import 'package:life_pilot/core/app_navigator.dart' as app_navigator;
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_item.dart';

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

Future<bool?> confirmEventTransfer(
      {required BuildContext context,
      required EventItem event,
      required ControllerEvent controllerEvent,
      required String fromTableName,
      required String toTableName,
      required AppLocalizations loc,
      required bool isAlreadyAdded}) async {

  final content = controllerEvent.buildTransferMessage(
    isAlreadyAdded: isAlreadyAdded,
    fromTableName: fromTableName,
    event: event,
    loc: loc,
  );

  return showConfirmationDialog(
    content: content,
    confirmText: loc.add,
    cancelText: loc.cancel,
  );
}

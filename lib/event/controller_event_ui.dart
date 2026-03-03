import 'package:flutter/material.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/page_event_add.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/utils/widgets/widgets_confirmation_dialog.dart';

Future<void> onEditPressed({
  required BuildContext context,
  required ControllerEvent controller,
  required EventItem event,
}) async {
  final updatedEvent = await Navigator.push<EventItem?>(
    context,
    MaterialPageRoute(
      builder: (_) => PageEventAdd(
        auth: controller.auth,
        controllerEvent: controller,
        tableName: controller.tableName,
        existingEvent: event.copyWith(),
      ),
    ),
  );

  await controller.onEditEvent(event: event, updatedEvent: updatedEvent);

  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop(); // 只有確定更新才關閉外層 dialog
  }
}

Future<void> onDeletePressed({
  required BuildContext context,
  required ControllerEvent controller,
  required EventItem event,
  required AppLocalizations loc,
}) async {
  if (!controller.canDelete(account: event.account ?? '')) {
    return;
  }

  final shouldDelete = await showConfirmationDialog(
    content: '${loc.eventDelete}「${event.name}」？',
    confirmText: loc.delete,
    cancelText: loc.cancel,
  );

  if (shouldDelete != true) return;

  try {
    await controller.deleteEvent(event);
    AppNavigator.showSnackBar(loc.deleteOk);
  } catch (e) {
    AppNavigator.showErrorBar('${loc.deleteError}: $e');
  }

  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop(true);
  }
}

Future<void> onMemoryCheckboxChanged({
  required BuildContext context,
  required ControllerEvent controller,
  required bool? value,
  required EventItem event,
  required String toTableName,
  required AppLocalizations loc,
}) async {
  final tmpValue = value ?? false;

  // 取消選擇直接 toggle
  if (!tmpValue) {
    controller.toggleEventSelection(event.id, false);
    return;
  }

  // 判斷是否已經存在
  final isAlreadyAdded = await controller.handleEventCheckboxIsAlreadyAdd(
      event, tmpValue, toTableName);

  // 顯示確認對話框
  final shouldTransfer = await confirmEventTransfer(
    context: context,
    event: event,
    controller: controller,
    fromTableName: controller.tableName,
    toTableName: toTableName,
    loc: loc,
    isAlreadyAdded: isAlreadyAdded,
  );

  if (shouldTransfer ?? false) {
    await controller.handleEventCheckboxTransfer(
        tmpValue, isAlreadyAdded, event, toTableName);
    AppNavigator.showSnackBar(loc.eventAddOk);
  } else {
    controller.toggleEventSelection(event.id, false);
  }
}
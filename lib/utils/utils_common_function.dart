import 'package:flutter/material.dart' hide DateUtils;
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:life_pilot/utils/utils_date_time.dart';
import 'package:life_pilot/utils/utils_enum.dart';
import 'package:life_pilot/utils/utils_show_dialog.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

final Logger logger = Logger(); // 只建立一次，全域可用

void showSnackBar(BuildContext context, String message) {
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

// 勾選 Checkbox 時的邏輯處理
Future<void> handleCheckboxChanged({
  required BuildContext context,
  required bool? value,
  required Event event,
  required Set<String> selectedEventIds,
  required void Function(void Function()) setState,
  required String addedMessage,
  required String tableName,
  required String toTableName,
}) async {
  ControllerAuth auth = Provider.of<ControllerAuth>(context, listen: false);
  final service = Provider.of<ServiceStorage>(context, listen: false);
  final now = DateUtils.dateOnly(DateTime.now());
  final loc = AppLocalizations.of(context)!;
  if (value == true) {
    final existingEvents = await service.getRecommendedEvents(
        tableName: toTableName, id: event.id, inputUser: auth.currentAccount);

    final isAlreadyAdded =
        existingEvents?.any((e) => e.id == event.id) ?? false;

    final shouldAdd = await showConfirmationDialog(
      context: context,
      content: isAlreadyAdded
          ? (tableName == constTableCalendarEvents ? loc.memory_add_error : loc.event_add_error)
          : '${tableName == constTableCalendarEvents ? loc.memory_add : loc.event_add}「${event.name}」？',
      confirmText: loc.add,
      cancelText: loc.cancel,
    );

    if (shouldAdd != true) {
      return;
    }

    setState(() {
      selectedEventIds.add(event.id);
    });

    if (!isAlreadyAdded || tableName == constTableRecommendedAttractions) {
      if (toTableName != constTableMemoryTrace && event.startDate != null && !event.startDate!.isAfter(now)) {
        event.startDate = now;
      }
      event.account = auth.currentAccount;
      if (tableName == constTableRecommendedAttractions) { //如果是安排景點，視同都是新的事件處理
        event.id = Uuid().v4();
      }
      await service.saveRecommendedEvent(
          context, event, true, toTableName);
    } else {
      List<SubEventItem> sortedSubEvents = List.from(event.subEvents);
      sortedSubEvents.sort((a, b) => a.startDate!.compareTo(b.startDate!));
      sortedSubEvents.removeWhere((subEvent) =>
          subEvent.startDate != null &&
          !subEvent.startDate!.isAfter(event.startDate!));
      if (sortedSubEvents.isNotEmpty) {
        for (var tmpEvent in sortedSubEvents) {
          Event subEvent = tmpEvent.toEvent().copyWith(
                newStartDate: tmpEvent.startDate != null &&
                        !tmpEvent.startDate!.isAfter(now)
                    ? now
                    : tmpEvent.startDate,
                newEndDate:
                    tmpEvent.endDate != null && !tmpEvent.endDate!.isAfter(now)
                        ? now
                        : tmpEvent.endDate,
              )
            ..masterGraphUrl = tmpEvent.masterGraphUrl ?? event.masterGraphUrl
            ..masterUrl = tmpEvent.masterUrl ?? event.masterUrl
            ..city = tmpEvent.city.isEmpty ? event.city : tmpEvent.city
            ..location =
                tmpEvent.location.isEmpty ? event.location : tmpEvent.location
            ..unit = tmpEvent.unit.isEmpty ? event.unit : tmpEvent.unit
            ..account = auth.currentAccount;
          await service.deleteRecommendedEvent(
              context, subEvent, toTableName);
          await service.saveRecommendedEvent(
              context, subEvent, true, toTableName);
        }
      } else {
        event.subEvents = sortedSubEvents;
        Event updatedEvent = event.copyWith(
            newStartDate:
                event.startDate != null && !event.startDate!.isAfter(now)
                    ? now
                    : event.startDate,
            newEndDate: event.endDate != null && !event.endDate!.isAfter(now)
                ? now
                : event.endDate);
        updatedEvent.account = auth.currentAccount;
        await service.deleteRecommendedEvent(
            context, updatedEvent, toTableName);
        await service.saveRecommendedEvent(
            context, updatedEvent, true, toTableName);
      }
    }
    if (!context.mounted) return; // 確保 context 還存在
    showSnackBar(context, addedMessage);
  } else {
    setState(() {
      selectedEventIds.remove(event.id);
    });
  }
}

// 移除事件邏輯
Future<void> handleRemoveEvent({
  required BuildContext context,
  required Event event,
  required Future<void> Function() onDelete,
  required VoidCallback onSuccessSetState,
}) async {
  final loc = AppLocalizations.of(context)!;
  final shouldDelete = await showConfirmationDialog(
    context: context,
    content: '${loc.event_delete}「${event.name}」？',
    confirmText: loc.delete,
    cancelText: loc.cancel,
  );

  if (shouldDelete == true) {
    try {
      await onDelete();
      onSuccessSetState();
      showSnackBar(context, loc.delete_ok);
    } catch (e) {
      showSnackBar(context, '${loc.delete_error}: $e');
    }
  }
}

// 過濾仍有效的事件
List<Event> filterValidEvents(List<Event> events) {
  final day = DateUtils.dateOnly(DateTime.now()).add(Duration(days: -1));

  return events.where((event) {
    if (event.endDate != null) {
      return !event.endDate!.isBefore(day);
    } else if (event.startDate != null) {
      return !event.startDate!.isBefore(day);
    } else {
      return false;
    }
  }).toList();
}

List<SubEventItem> sortSubEvents(List<SubEventItem> list) {
  list.sort((a, b) {
    final aStart = a.startDate ?? DateTime(9999);
    final bStart = b.startDate ?? DateTime(9999);
    final cmpStartDate = aStart.compareTo(bStart);
    if (cmpStartDate != 0) return cmpStartDate;

    final aStartTime = a.startTime ?? const TimeOfDay(hour: 23, minute: 59);
    final bStartTime = b.startTime ?? const TimeOfDay(hour: 23, minute: 59);
    final cmpStartTime =
        DateTimeCompare.compareTimeOfDay(aStartTime, bStartTime);
    if (cmpStartTime != 0) return cmpStartTime;

    final aEnd = a.endDate ?? DateTime(9999);
    final bEnd = b.endDate ?? DateTime(9999);
    final cmpEndDate = aEnd.compareTo(bEnd);
    if (cmpEndDate != 0) return cmpEndDate;

    final aEndTime = a.endTime ?? const TimeOfDay(hour: 23, minute: 59);
    final bEndTime = b.endTime ?? const TimeOfDay(hour: 23, minute: 59);
    return DateTimeCompare.compareTimeOfDay(aEndTime, bEndTime);
  });
  return list;
}

// 登入錯誤顯示
void showLoginError(BuildContext context, String result) {
  AppLocalizations loc = AppLocalizations.of(context)!;
  final errorMessages = {
    ErrorFields.wrongUserPassword: loc.wrongUserPassword,
    ErrorFields.tooManyRequestsError: loc.tooManyRequests,
    ErrorFields.networkRequestFailedError: loc.networkError,
    ErrorFields.invalidEmailError: loc.invalidEmail,
    ErrorFields.noEmailError: loc.noEmailError,
    ErrorFields.noPasswordError: loc.noPasswordError,
    ErrorFields.loginError: loc.loginError,
    ErrorFields.resetPasswordEmailNotFoundError: loc.resetPasswordEmailNotFound,
    ErrorFields.emailAlreadyInUseError: loc.emailAlreadyInUse,
    ErrorFields.weakPasswordError: loc.weakPassword,
    ErrorFields.registerError: loc.registerError,
    ErrorFields.logoutError: loc.logoutError,
  };
  final errorMessage = errorMessages[result] ?? loc.unknownError;
  showSnackBar(context, errorMessage);
}

Future<List<Event>> loadEvents(String tableName, {required BuildContext context}) async {
   ControllerAuth auth = Provider.of<ControllerAuth>(context, listen: false);
   final service = Provider.of<ServiceStorage>(context, listen: false);
  final recommended = await service.getRecommendedEvents(tableName: tableName, inputUser: auth.currentAccount);
  return recommended ?? [];
}

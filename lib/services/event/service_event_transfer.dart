import 'package:flutter/material.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/services/event/service_event.dart';
import 'package:uuid/uuid.dart';

class ServiceEventTransfer {
  final String currentAccount;
  final ServiceEvent serviceEvent;

  ServiceEventTransfer({
    required this.currentAccount,
    required this.serviceEvent,
  });

  Future<bool> toggleEventTransferIsAlreadyAdd({
    required EventItem event,
    required String toTableName,
    required bool? isChecked,
  }) async {
    if (isChecked != true) return false;

    final now = DateUtils.dateOnly(DateTime.now());

    final existingEvents = await serviceEvent.getEvents(
      tableName: toTableName,
      id: event.id,
      inputUser: currentAccount,
      dateS: now.subtract(Duration(days: 366)),
    );

    return existingEvents?.any((e) => e.id == event.id) ?? false;
  }

  Future<EventItem?> toggleEventTransfer({
    required EventItem event,
    required String fromTableName,
    required String toTableName,
    required bool? isChecked,
    required bool isAlreadyAdded,
  }) async {
    if (isChecked != true) return null;

    final now = DateUtils.dateOnly(DateTime.now());
    if (!isAlreadyAdded || fromTableName == TableNames.recommendedAttractions) {
      if (toTableName != TableNames.memoryTrace &&
          event.startDate != null &&
          !event.startDate!.isAfter(now)) {
        event.startDate = now;
      }
      event.account = currentAccount;
      if (fromTableName == TableNames.recommendedAttractions) {
        event.id = Uuid().v4();
      }
      await serviceEvent.saveEvent(
        currentAccount: currentAccount,
        event: event,
        isNew: true,
        tableName: toTableName,
      );
      return event;
    } else {
      List<EventItem> sortedSubEvents = List.from(event.subEvents);
      sortedSubEvents.sort((a, b) => a.startDate!.compareTo(b.startDate!));
      sortedSubEvents.removeWhere((subEvent) =>
          !subEvent.startDate!.isAfter(event.startDate!) && (subEvent.endDate == null || !subEvent.endDate!.isAfter(event.startDate!)));
      if (sortedSubEvents.isNotEmpty) {
        final tmpEvent = sortedSubEvents[0];
        EventItem subEvent = tmpEvent.copyWith(
          newStartDate:
              tmpEvent.startDate != null && !tmpEvent.startDate!.isAfter(now)
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
          ..account = currentAccount;
        await serviceEvent.deleteEvent(
            currentAccount: currentAccount,
            event: subEvent,
            tableName: toTableName);
        await serviceEvent.saveEvent(
            currentAccount: currentAccount,
            event: subEvent,
            isNew: true,
            tableName: toTableName);
        return subEvent;
      } else {
        event.subEvents = sortedSubEvents;
        EventItem updatedEvent = event.copyWith(
            newId: Uuid().v4(),
            newStartDate:
                event.startDate != null && !event.startDate!.isAfter(now)
                    ? now
                    : event.startDate,
            newEndDate: event.endDate != null && !event.endDate!.isAfter(now)
                ? now
                : event.endDate);
        updatedEvent.account = currentAccount;
        //await service.deleteEvent(event: updatedEvent, tableName: toTableName);
        await serviceEvent.saveEvent(
            currentAccount: currentAccount,
            event: updatedEvent,
            isNew: true,
            tableName: toTableName);
        return updatedEvent;
      }
    }
  }
}

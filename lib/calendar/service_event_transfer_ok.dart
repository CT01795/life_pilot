import 'package:flutter/material.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
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
      return _transferNewEvent(event, toTableName, now, fromTableName);
    }

    final sortedSubEvents = _getValidSubEvents(event, now);

    if (sortedSubEvents.isNotEmpty) {
      return _transferSubEvent(event, sortedSubEvents.first, toTableName, now);
    }

    return _transferFallbackEvent(event, toTableName, now);
  }

  // ----------------------- 私有方法 -----------------------
  DateTime _normalizeDate(DateTime? date, DateTime now) {
    if (date == null) return now;
    return !date.isAfter(now) ? now : date;
  }

  Future<EventItem> _transferNewEvent(EventItem event, String toTableName,
      DateTime now, String fromTableName) async {
    if (toTableName != TableNames.memoryTrace &&
        event.startDate != null &&
        !event.startDate!.isAfter(now)) {
      event.startDate = now;
    }
    event.account = currentAccount;

    if (fromTableName == TableNames.recommendedAttractions) {
      event.id = Uuid().v4();
      event.endDate = event.startDate;
    }

    await serviceEvent.saveEvent(
      currentAccount: currentAccount,
      event: event,
      isNew: true,
      tableName: toTableName,
    );
    return event;
  }

  List<EventItem> _getValidSubEvents(EventItem event, DateTime now) {
    final sortedSubEvents = List<EventItem>.from(event.subEvents)
      ..sort((a, b) => a.startDate!.compareTo(b.startDate!));

    sortedSubEvents.removeWhere((subEvent) =>
        !subEvent.startDate!.isAfter(event.startDate!) &&
        (subEvent.endDate == null ||
            !subEvent.endDate!.isAfter(event.startDate!)));

    return sortedSubEvents;
  }

  Future<EventItem> _transferSubEvent(EventItem masterEvent, EventItem subEvent,
      String toTableName, DateTime now) async {
    final updatedSubEvent = subEvent.copyWith(
      newStartDate: _normalizeDate(subEvent.startDate, now),
      newEndDate: _normalizeDate(subEvent.endDate, now),
      newMasterGraphUrl: subEvent.masterGraphUrl ?? masterEvent.masterGraphUrl,
      newMasterUrl: subEvent.masterUrl ?? masterEvent.masterUrl,
      newCity: subEvent.city.isEmpty ? masterEvent.city : subEvent.city,
      newLocation: subEvent.location.isEmpty ? masterEvent.location : subEvent.location,
      newUnit: subEvent.unit.isEmpty ? masterEvent.unit : subEvent.unit,
      newAccount: currentAccount,
    );

    await serviceEvent.deleteEvent(
      currentAccount: currentAccount,
      event: updatedSubEvent,
      tableName: toTableName,
    );
    await serviceEvent.saveEvent(
      currentAccount: currentAccount,
      event: updatedSubEvent,
      isNew: true,
      tableName: toTableName,
    );

    return updatedSubEvent;
  }

  Future<EventItem> _transferFallbackEvent(
      EventItem event, String toTableName, DateTime now) async {
    event.subEvents = [];
    final updatedEvent = event.copyWith(
      newId: Uuid().v4(),
      newStartDate: _normalizeDate(event.startDate, now),
      newEndDate: _normalizeDate(event.endDate, now),
    )..account = currentAccount;

    await serviceEvent.saveEvent(
      currentAccount: currentAccount,
      event: updatedEvent,
      isNew: true,
      tableName: toTableName,
    );
    return updatedEvent;
  }
}

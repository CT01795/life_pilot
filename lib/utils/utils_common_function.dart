import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_recommended_event.dart';
import 'package:life_pilot/providers/provider_locale.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:uuid/uuid.dart';

void toggleLocale(ProviderLocale providerLocale) {
  final supportedLocales = [Locale('en'), Locale('zh')];
  final currentIndex = supportedLocales
      .indexWhere((l) => l.languageCode == providerLocale.locale.languageCode);
  final nextIndex = (currentIndex + 1) % supportedLocales.length;
  providerLocale.setLocale(supportedLocales[nextIndex]);
}

void showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

extension TimeOfDayExtension on TimeOfDay {
  String formatTimeString() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

extension StringTimeOfDay on String {
  TimeOfDay parseToTimeOfDay() {
    final parts = split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}

Future<void> handleCheckboxChanged({
  required BuildContext context,
  required ServiceStorage serviceStorage,
  required bool? value,
  required RecommendedEvent event,
  required Set<String> selectedEventIds,
  required void Function(void Function()) setState,
  required String addedMessage,
}) async {
  final loc = AppLocalizations.of(context)!;
  if (value == true) {
    final existingEvents = await serviceStorage.getRecommendedEvents();

    final isAlreadyAdded = existingEvents!.any((e) => e.id == event.id);

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
            '${isAlreadyAdded ? loc.event_add_tp_plan_error : "${loc.event_add}「${event.name}」"}？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(loc.add, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldAdd != true) {
      return;
    }

    setState(() {
      selectedEventIds.add(event.id);
    });

    if (isAlreadyAdded) {
      List<SubRecommendedEventItem> sortedSubEvents =
          List.from(event.subRecommendedEvents);

      sortedSubEvents.sort((a, b) => a.startDate!.compareTo(b.startDate!));

      sortedSubEvents.removeWhere((subEvent) =>
          subEvent.startDate != null &&
          !subEvent.startDate!.isAfter(event.startDate!));

      RecommendedEvent updatedEvent = RecommendedEvent(
        id: Uuid().v4(), 
        masterGraphUrl: event.masterGraphUrl,
        startDate:
            !event.startDate!.isAfter(DateTime.now().add(Duration(days: -1)))
                ? DateTime.now()
                : event.startDate,
        endDate: event.endDate,
        startTime: event.startTime,
        endTime: event.endTime,
        city: event.city,
        location: event.location,
        name: event.name,
        type: event.type,
        description: event.description,
        fee: event.fee,
        unit: event.unit,
        subRecommendedEvents: sortedSubEvents, 
        subGraphs: event.subGraphs,
      );
      await serviceStorage.saveRecommendedEvent(context, updatedEvent, true);
      showSnackBar(context, addedMessage);
      return;
    }

    if (!event.startDate!.isAfter(DateTime.now().add(Duration(days: -1)))) {
      event.startDate = DateTime.now().add(Duration(days: -1));
    }
    await serviceStorage.saveRecommendedEvent(context, event, true);
    showSnackBar(context, addedMessage);
  } else {
    setState(() {
      selectedEventIds.remove(event.id);
    });
  }
}

Future<void> handleRemoveEvent({
  required BuildContext context,
  required RecommendedEvent event,
  required Future<void> Function() onDelete,
  required VoidCallback onSuccessSetState,
}) async {
  final loc = AppLocalizations.of(context)!;
  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text('${loc.event_delete}「${event.name}」？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(loc.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(loc.delete, style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
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

List<RecommendedEvent> filterValidEvents(List<RecommendedEvent> events) {
  final day = DateTime.now().add(Duration(days: -1));
  final dayDate = DateTime(day.year, day.month, day.day);

  return events.where((event) {
    if (event.endDate != null) {
      return !event.endDate!.isBefore(dayDate);
    } else if (event.startDate != null) {
      return !event.startDate!.isBefore(dayDate);
    } else {
      return false; 
    }
  }).toList();
}

List<SubRecommendedEventItem> sortSubEvents(List<SubRecommendedEventItem> list) {
  list.sort((a, b) {
    final aStart = a.startDate ?? DateTime(9999);
    final bStart = b.startDate ?? DateTime(9999);
    final cmpStartDate = aStart.compareTo(bStart);
    if (cmpStartDate != 0) return cmpStartDate;

    final aStartTime = a.startTime ?? const TimeOfDay(hour: 23, minute: 59);
    final bStartTime = b.startTime ?? const TimeOfDay(hour: 23, minute: 59);
    final cmpStartTime = compareTimeOfDay(aStartTime, bStartTime);
    if (cmpStartTime != 0) return cmpStartTime;

    final aEnd = a.endDate ?? DateTime(9999);
    final bEnd = b.endDate ?? DateTime(9999);
    final cmpEndDate = aEnd.compareTo(bEnd);
    if (cmpEndDate != 0) return cmpEndDate;

    final aEndTime = a.endTime ?? const TimeOfDay(hour: 23, minute: 59);
    final bEndTime = b.endTime ?? const TimeOfDay(hour: 23, minute: 59);
    return compareTimeOfDay(aEndTime, bEndTime);
  });
  return list;
}

String formatEventDateTime(var event, String type) {
  DateTime? date;

  if (type == "S" && event.startDate != null && event.startTime != null) {
    date = DateTime(event.startDate!.year, event.startDate!.month,
        event.startDate!.day, event.startTime!.hour, event.startTime!.minute);
  } else if (type == "S" && event.startDate != null) {
    date = DateTime(
        event.startDate!.year, event.startDate!.month, event.startDate!.day);
  } else if (type == "E" && event.endDate != null && event.endTime != null) {
    date = DateTime(event.endDate!.year, event.endDate!.month,
        event.endDate!.day, event.endTime!.hour, event.endTime!.minute);
    if (_isSameDay(event.startDate, event.endDate)) {
      return DateFormat('HH:mm').format(date);
    } else if (_isSameYear(event.startDate, event.endDate)) {
      return DateFormat('MM/dd HH:mm').format(date);
    }
  } else if (type == "E" && event.endDate != null) {
    date =
        DateTime(event.endDate!.year, event.endDate!.month, event.endDate!.day);
    if (_isSameDay(event.startDate, event.endDate)) {
      return '';
    } else if (_isSameYear(event.startDate, event.endDate)) {
      return DateFormat('MM/dd HH:mm').format(date);
    }
  } else if (type == "E" && event.endTime != null && event.startDate != null) {
    date = DateTime(event.startDate!.year, event.startDate!.month,
        event.startDate!.day, event.endTime!.hour, event.endTime!.minute);
    return DateFormat('HH:mm').format(date);
  }

  if (date == null) return '';
  return date.year == DateTime.now().year
      ? DateFormat('MM/dd HH:mm').format(date)
      : DateFormat('yyyy/MM/dd HH:mm').format(date);
}

bool _isSameDay(DateTime? a, DateTime? b) =>
    a != null &&
    b != null &&
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day;

bool _isSameYear(DateTime? a, DateTime? b) =>
    a != null && b != null && a.year == b.year;

int compareTimeOfDay(TimeOfDay a, TimeOfDay b) {
  final aMinutes = a.hour * 60 + a.minute;
  final bMinutes = b.hour * 60 + b.minute;
  return aMinutes.compareTo(bMinutes);
}

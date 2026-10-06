import 'package:flutter/material.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:uuid/uuid.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';

class CalendarService {
  Future<bool> _storesLocally(String account) async =>
      await LocalDataStore.instance.preferredLocation(account) ==
      DataStorageLocation.local;

  /// 檢查是否已加入
  Future<bool> existsRecommendedEventToCal({
    required String account,
    required RecommendedEvent event,
  }) async {
    if (await _storesLocally(account)) {
      return LocalDataStore.instance.contains(
        owner: account,
        resource: TableNames.calendarEvents,
        id: event.id,
      );
    }
    final result = await supabase
        .from(TableNames.calendarEvents)
        .select(Fields.id)
        .eq(Fields.id, event.id)
        .eq(Fields.account, account)
        .maybeSingle();
    return result != null;
  }

  /// 加入行事曆
  Future<CalendarEvent> addRecommendedEventToCal({
    required String account,
    required RecommendedEvent event,
    required String? id,
    DateTime? scheduledDate,
    TimeOfDay? scheduledTime,
  }) async {
    final today = DateTimeFormatter.dateOnly(DateTime.now());
    final originalStart = event.startDate ?? today;
    final startDate =
        scheduledDate ??
        (DateTimeFormatter.dateOnly(originalStart).isBefore(today)
            ? today
            : originalStart);
    final data = <String, Object?>{
      // 新的 id
      Fields.id: id ?? const Uuid().v4(),
      Fields.account: account,
      'master_url': event.masterUrl,
      'start_date': startDate.toUtc().toIso8601String(),
      // Items transferred from recommendations are always single-day entries.
      'end_date': null,
      'start_time': (scheduledTime ?? event.startTime)?.formatTimeString(),
      'end_time': event.endTime?.formatTimeString(),
      EventFields.country: event.country,
      'city': event.city,
      'location': event.location,
      'name': event.name,
      'type': event.type,
      'description': event.description,
      'is_completed': false,
    };
    if (await _storesLocally(account)) {
      await LocalDataStore.instance.put(
        owner: account,
        resource: TableNames.calendarEvents,
        id: data[Fields.id]!.toString(),
        data: data,
      );
      return CalendarEvent.fromJson(data);
    }
    await supabase.from(TableNames.calendarEvents).insert(data);
    return CalendarEvent.fromJson(data);
  }

  /// 檢查是否已加入
  Future<bool> existsRecommendedPlaceToCal({
    required String account,
    required RecommendedPlace place,
    DateTime? scheduledDate,
  }) async {
    final selectedDate = DateTimeFormatter.dateOnly(
      scheduledDate ?? DateTime.now(),
    );
    if (await _storesLocally(account)) {
      final rows = await LocalDataStore.instance.list(
        owner: account,
        resource: TableNames.calendarEvents,
      );
      return rows.any((row) {
        final date = DateTime.tryParse(
          row['start_date']?.toString() ?? '',
        )?.toLocal();
        return _sameText(row['name'], place.name) &&
            _sameText(row[EventFields.country], place.country) &&
            _sameText(row['city'], place.city) &&
            _sameText(row['location'], place.location) &&
            date != null &&
            DateUtils.isSameDay(date, selectedDate);
      });
    }
    final nextDate = selectedDate.add(const Duration(days: 1));
    final result = await supabase
        .from(TableNames.calendarEvents)
        .select('name,country,city,location,start_date')
        .eq(Fields.account, account)
        .gte('start_date', selectedDate.toUtc().toIso8601String())
        .lt('start_date', nextDate.toUtc().toIso8601String())
        .limit(20);
    return result.any(
      (row) =>
          _sameText(row['name'], place.name) &&
          _sameText(row[EventFields.country], place.country) &&
          _sameText(row['city'], place.city) &&
          _sameText(row['location'], place.location),
    );
  }

  bool _sameText(Object? left, Object? right) =>
      (left?.toString() ?? '').trim().toLowerCase() ==
      (right?.toString() ?? '').trim().toLowerCase();

  /// 加入行事曆
  Future<CalendarEvent> addRecommendedPlaceToCal({
    required String account,
    required RecommendedPlace place,
    required String? id,
    DateTime? scheduledDate,
    TimeOfDay? scheduledTime,
  }) async {
    final now = DateTime.now();
    final localDate = DateTimeFormatter.dateOnly(scheduledDate ?? now);
    final data = <String, Object?>{
      // 新的 id
      Fields.id: id ?? const Uuid().v4(),
      Fields.account: account,
      'master_url': place.masterUrl,
      'start_date': localDate.toUtc().toIso8601String(),
      'end_date': null,
      'start_time': (scheduledTime ?? TimeOfDay.fromDateTime(now))
          .formatTimeString(),
      'end_time': null,
      EventFields.country: place.country,
      'city': place.city,
      'location': place.location,
      'name': place.name,
      'type': place.type,
      'description': place.description,
      'is_completed': false,
    };
    if (await _storesLocally(account)) {
      await LocalDataStore.instance.put(
        owner: account,
        resource: TableNames.calendarEvents,
        id: data[Fields.id]!.toString(),
        data: data,
      );
      return CalendarEvent.fromJson(data);
    }
    await supabase.from(TableNames.calendarEvents).insert(data);
    return CalendarEvent.fromJson(data);
  }

  Future<bool> existsCalendarEventToMemory({
    required String account,
    required CalendarEvent event,
  }) async {
    if (await _storesLocally(account)) {
      return LocalDataStore.instance.contains(
        owner: account,
        resource: TableNames.memoryTrace,
        id: event.id,
      );
    }
    final result = await supabase
        .from(TableNames.memoryTrace)
        .select(Fields.id)
        .eq(Fields.id, event.id)
        .eq(Fields.account, account)
        .maybeSingle();
    return result != null;
  }

  /// 加入回憶
  Future<void> addCalendarEventToMemory({
    required String account,
    required CalendarEvent event,
    required String? id,
    DateTime? selectedDate,
  }) async {
    final memoryDate = selectedDate ?? DateTime.now();
    final data = <String, Object?>{
      // 新的 id
      Fields.id: id ?? const Uuid().v4(),
      Fields.account: account,
      'master_url': event.masterUrl,
      'start_date': event.startDate?.toUtc().toIso8601String(),
      'end_date': event.endDate?.toUtc().toIso8601String(),
      'start_time': event.startTime?.formatTimeString(),
      'end_time': event.endTime?.formatTimeString(),
      EventFields.country: event.country,
      'city': event.city,
      'location': event.location,
      'name': event.name,
      'type': event.type,
      'description': event.description,
      EventFields.subEvents: event.subEventsForDate(memoryDate),
      'is_completed': false,
    };
    if (await _storesLocally(account)) {
      await LocalDataStore.instance.put(
        owner: account,
        resource: TableNames.memoryTrace,
        id: data[Fields.id]!.toString(),
        data: data,
      );
      return;
    }
    await supabase.from(TableNames.memoryTrace).insert(data);
  }
}

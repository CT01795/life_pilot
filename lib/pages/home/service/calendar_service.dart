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
        .eq(
          Fields.id,
          event.id,
        )
        .eq(
          Fields.account,
          account,
        )
        .maybeSingle();
    return result != null;
  }

  /// 加入行事曆
  Future<void> addRecommendedEventToCal({
    required String account,
    required RecommendedEvent event,
    required String? id,
  }) async {
    DateTime today = DateTimeFormatter.dateOnly(DateTime.now().toUtc());
    final data = <String, Object?>{
      // 新的 id
      Fields.id: id ?? const Uuid().v4(),
      Fields.account: account,
      'master_url': event.masterUrl,
      'start_date': event.startDate!.toUtc().isBefore(today)
          ? today.toIso8601String()
          : event.startDate?.toUtc().toIso8601String(),
      'end_date': event.endDate?.toUtc().toIso8601String(),
      'start_time': event.startTime?.formatTimeString(),
      'end_time': event.endTime?.formatTimeString(),
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
      return;
    }
    await supabase.from(TableNames.calendarEvents).insert(data);
  }

  /// 檢查是否已加入
  Future<bool> existsRecommendedPlaceToCal({
    required String account,
    required RecommendedPlace place,
  }) async {
    if (await _storesLocally(account)) {
      final today = DateTimeFormatter.dateOnly(DateTime.now());
      final rows = await LocalDataStore.instance.list(
        owner: account,
        resource: TableNames.calendarEvents,
      );
      return rows.any((row) {
        final date =
            DateTime.tryParse(row['start_date']?.toString() ?? '')?.toLocal();
        return row['name']?.toString() == place.name &&
            date != null &&
            DateUtils.isSameDay(date, today);
      });
    }
    final result = await supabase
        .from(TableNames.calendarEvents)
        .select(Fields.id)
        .eq(
          "name",
          place.name,
        )
        .eq(
          Fields.account,
          account,
        )
        .eq(
            "start_date",
            DateTimeFormatter.dateOnly(DateTime.now().toUtc())
                .toIso8601String())
        .maybeSingle();
    return result != null;
  }

  /// 加入行事曆
  Future<void> addRecommendedPlaceToCal({
    required String account,
    required RecommendedPlace place,
    required String? id,
  }) async {
    final data = <String, Object?>{
      // 新的 id
      Fields.id: id ?? const Uuid().v4(),
      Fields.account: account,
      'master_url': place.masterUrl,
      'start_date':
          DateTimeFormatter.dateOnly(DateTime.now().toUtc()).toIso8601String(),
      'end_date': null,
      'start_time': TimeOfDay.fromDateTime(DateTime.now()).formatTimeString(),
      'end_time': null,
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
      return;
    }
    await supabase.from(TableNames.calendarEvents).insert(data);
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
        .eq(
          Fields.id,
          event.id,
        )
        .eq(
          Fields.account,
          account,
        )
        .maybeSingle();
    return result != null;
  }

  /// 加入回憶
  Future<void> addCalendarEventToMemory({
    required String account,
    required CalendarEvent event,
    required String? id,
  }) async {
    final data = <String, Object?>{
      // 新的 id
      Fields.id: id ?? const Uuid().v4(),
      Fields.account: account,
      'master_url': event.masterUrl,
      'start_date': event.startDate?.toUtc().toIso8601String(),
      'end_date': event.endDate?.toUtc().toIso8601String(),
      'start_time': event.startTime?.formatTimeString(),
      'end_time': event.endTime?.formatTimeString(),
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
        resource: TableNames.memoryTrace,
        id: data[Fields.id]!.toString(),
        data: data,
      );
      return;
    }
    await supabase.from(TableNames.memoryTrace).insert(data);
  }
}

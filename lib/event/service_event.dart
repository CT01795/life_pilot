import 'package:flutter/material.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceEvent {
  final client = Supabase.instance.client;
  ServiceEvent();

  Future<String> getKey({required String keyName}) async {
    try {
      return await client.rpc('get_key', params: {'p_key_name': keyName});
    } catch (e) {
      logger.e('Error fetching key: $e');
      return '';
    }
  }

  // 📌 取得推薦事件 (由 Supabase 的 RPC 呼叫)
  Future<List<EventItem>?> getEvents({
    required String tableName,
    DateTime? dateS,
    DateTime? dateE,
    String? id,
    String? inputUser,
  }) async {
    final today = DateTimeFormatter.dateOnly(DateTime.now());
    final cutoffDate = today.subtract(Duration(days: 2));
    if (tableName == TableNames.recommendedEvents) {
      await client.from(tableName).delete().or(
            '${EventFields.endDate}.lte.$cutoffDate,'
            'and(${EventFields.endDate}.is.null,${EventFields.startDate}.lte.$cutoffDate)',
          );
      await client.from(TableNames.recommendedEventsDeleted).delete().or(
            '${EventFields.endDate}.lte.$cutoffDate,'
            'and(${EventFields.endDate}.is.null,${EventFields.startDate}.lte.$cutoffDate)',
          );
      await client.from(TableNames.recommendedEventUrl).delete().lte('start_date',cutoffDate);
    }
    final inputDateS = (dateS ??
            (tableName == TableNames.memoryTrace
                ? DateTime(today.year - 1, today.month, today.day)
                : today))
        .formatDateString();
    final inputDateE =
        (dateE ?? DateTime(today.year + 2, today.month, today.day))
            .formatDateString();

    final response = await client.rpc('get_filtered_$tableName', params: {
      'payload': {
        'inputid': id,
        'inputdates': inputDateS, // 傳 YYYY-MM-DD 格式給 SQL
        'inputdatee': inputDateE, // 傳 YYYY-MM-DD 格式給 SQL
        'inputuser': inputUser,
      }
    });

    final events = (response as List)
        .map((e) => EventItem.fromJson(json: e as Map<String, dynamic>))
        .toList()
        .map((e) {
      e.startDate = e.startDate?.toLocal();
      e.endDate = e.endDate?.toLocal();
      return e;
    }).toList();
    return events;
  }

  // 💾 儲存（新增或更新）事件 + 排程通知
  Future<void> saveEvent(
      {required String currentAccount,
      required EventItem event,
      required bool isNew,
      required String tableName}) async {
    try {
      _validateEvent(event: event);
      if ((isNew || event.reminderOptions.isEmpty) &&
          tableName == TableNames.calendarEvents) {
        event.reminderOptions = [
          CalendarReminderOption.oneHour, // 事件開始前1小時
          CalendarReminderOption.sameDay8am,
          CalendarReminderOption.dayBefore8am // 前一天早上8點
        ];
      }

      if (event.repeatOptions.key.isEmpty) {
        event.repeatOptions = CalendarRepeatRule.once;
      }

      event.endDate = _normalizeEndDate(event.startDate, event.endDate);
      event.endTime = _normalizeEndTime(
          event.startTime, event.endTime, event.startDate, event.endDate);

      for (final subEvent in event.subEvents) {
        subEvent.endDate =
            _normalizeEndDate(subEvent.startDate, subEvent.endDate);
        subEvent.endTime = _normalizeEndTime(subEvent.startTime,
            subEvent.endTime, subEvent.startDate, subEvent.endDate);
      }

      event.account = currentAccount;
      event.isApproved = false;
      final Map<String, dynamic> data = event.toJson();
      if (isNew) {
        await client.from(tableName).insert([data]); //'recommended_events'
      } else {
        var query =
            client.from(tableName).update(data).eq(EventFields.id, event.id);
        if (currentAccount != AuthConstants.sysAdminEmail &&
            event.account != null &&
            event.account!.isNotEmpty) {
          query = query.eq(EventFields.account, event.account!); // ✅ 明確保證非 null
        }
        await query;
      }
    } catch (ex, stacktrace) {
      logger.e("saveEvent error", error: ex, stackTrace: stacktrace);
      rethrow;
    }
  }

  // ❌ 刪除推薦事件
  Future<void> deleteEvent(
      {required String currentAccount,
      required EventItem event,
      required String tableName}) async {
    try {
      if (tableName == TableNames.recommendedEvents){
        final Map<String, dynamic> data = event.toJson();
        await client.from(TableNames.recommendedEventsDeleted).upsert([data]);
      }
      var query = client.from(tableName).delete().eq(EventFields.id, event.id);
      if (currentAccount != AuthConstants.sysAdminEmail &&
          event.account != null &&
          event.account!.isNotEmpty) {
        query = query.eq(EventFields.account, event.account!);
      }
      await query;
    } catch (ex, stacktrace) {
      logger.e("deleteEvent error", error: ex, stackTrace: stacktrace);
      rethrow;
    }
  }

  // ✅ 核准事件 (由管理者)
  Future<void> approvalEvent(
      {required EventItem event, required String tableName}) async {
    try {
      final Map<String, dynamic> data = event.toJson();
      var query =
          client.from(tableName).update(data).eq(EventFields.id, event.id);
      await query;
    } catch (ex, stacktrace) {
      logger.e("approvalEvent error", error: ex, stackTrace: stacktrace);
      rethrow;
    }
  }

  Future<void> updateLikeEvent(
      {required EventItem event, required String account}) async {
    try {
      final Map<String, dynamic> data = {
        "id": event.id,
        "is_like": event.isLike,
        "is_dislike": event.isDislike,
        "account": account
      };
      var query = client.from(TableNames.recommendedEventsFavor).upsert(data);
      await query;
    } catch (ex, stacktrace) {
      logger.e("approvalEvent error", error: ex, stackTrace: stacktrace);
      rethrow;
    }
  }

  Future<void> incrementEventCounter({
    required String? eventId,
    required String? eventName,
    required String column,
    required String account,
  }) async {
    try {
      await client.rpc(
        'increment_event_counter',
        params: {
          'p_event_id': eventId,
          'p_event_name': eventName,
          'p_column': column,
          'p_account': account,
        },
      );
    } catch (e) {
      logger.e('Error incrementEventCounter $column: $e');
    }
  }

  // --- 私有方法 ---
  void _validateEvent({required EventItem event}) {
    if (event.name.isEmpty) {
      throw Exception("event_save_error");
    }
  }

  DateTime? _normalizeEndDate(DateTime? start, DateTime? end) {
    if (end != null && !end.isAfter(start!)) return null;
    return end;
  }

  TimeOfDay? _normalizeEndTime(TimeOfDay? startTime, TimeOfDay? endTime,
      DateTime? startDate, DateTime? endDate) {
    if ((endDate == null || endDate == startDate) &&
        endTime != null &&
        !endTime.isAfter(startTime!)) {
      return null;
    }
    return endTime;
  }
}

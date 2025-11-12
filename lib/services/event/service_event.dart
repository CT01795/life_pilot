// lib/services/event_service.dart
import 'package:flutter/material.dart' hide DateUtils;
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/date_time.dart';
import 'package:life_pilot/core/calendar/utils_calendar.dart';
import 'package:life_pilot/models/event/model_event_fields.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/core/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceEvent{
  final client = Supabase.instance.client;
  ServiceEvent();

  Future<String> getKey({required String keyName}) async {
    try {
      final response = await client.rpc('get_key', params: {'p_key_name': keyName});

      // Supabase RPC 通常回傳 List<dynamic>
      if (response != null && response is List && response.isNotEmpty) {
        // 假設 function 回傳 { key: "xxxx" }
        final data = response.first;
        if (data is Map<String, dynamic> && data.containsKey('key')) {
          return data['key'] as String;
        }
      }

      return constEmpty;
    } catch (e) {
      logger.e('Error fetching key: $e');
      return constEmpty;
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
    final today = DateUtils.dateOnly(DateTime.now());
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
        .toList();
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
          ReminderOption.oneHour, // 事件開始前1小時
          ReminderOption.sameDay8am,
          ReminderOption.dayBefore8am // 前一天早上8點
        ];
      }

      if (event.repeatOptions.key.isEmpty) {
        event.repeatOptions = RepeatRule.once;
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
      String? realAccount = event.account;
      if (event.account == AuthConstants.guest) {
        event.account = AuthConstants.sysAdminEmail;
      }
      final Map<String, dynamic> data = event.toJson();
      var query =
          client.from(tableName).update(data).eq(EventFields.id, event.id);
      if (realAccount != null &&
          realAccount.isNotEmpty &&
          realAccount != AuthConstants.guest) {
        query = query.eq(EventFields.account, event.account!); // ✅ 明確保證非 null
      }
      await query;
    } catch (ex, stacktrace) {
      logger.e("approvalEvent error", error: ex, stackTrace: stacktrace);
      rethrow;
    }
  }

  // --- 私有方法 ---
  void _validateEvent(
      {required EventItem event}) {
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

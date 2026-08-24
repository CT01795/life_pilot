import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/event/event_save_exception.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/event_city_normalizer.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceEvent {
  ServiceEvent();

  static DateTime? _lastCleanupRequestDate;
  static Future<void>? _cleanupRequest;

  bool get _isCurrentUserAdmin =>
      supabase.auth.currentUser?.appMetadata['role'] == AuthConstants.adminRole;

  Future<void> _cleanupRecommendedEventsOncePerDay(DateTime today) async {
    if (_lastCleanupRequestDate == today) return;
    final activeRequest = _cleanupRequest;
    if (activeRequest != null) return activeRequest;

    final request = () async {
      try {
        await apiSupabase.post(
          'event/cleanup_recommended_events',
          const {},
        );
        _lastCleanupRequestDate = today;
      } catch (error, stackTrace) {
        logger.e(
          'Daily recommended event cleanup failed',
          error: error,
          stackTrace: stackTrace,
        );
      } finally {
        _cleanupRequest = null;
      }
    }();
    _cleanupRequest = request;
    return request;
  }

  // 📌 取得推薦事件
  Future<List<EventItem>?> getEvents({
    required String tableName,
    DateTime? dateS,
    DateTime? dateE,
    String? id,
    String? inputUser,
  }) async {
    final today = DateTimeFormatter.dateOnly(DateTime.now());
    if (tableName == TableNames.recommendEvents) {
      unawaited(_cleanupRecommendedEventsOncePerDay(today));
    }
    final inputDateS = (dateS ??
            (tableName == TableNames.memoryTrace
                ? DateTime(today.year, today.month, today.day)
                    .subtract(Duration(days: 60))
                : today))
        .formatDateString();
    final inputDateE =
        (dateE ?? DateTime(today.year + 2, today.month, today.day))
            .formatDateString();

    try {
      final response = await supabase.rpc(
        'get_filtered_$tableName',
        params: {
          'payload': {
            'table_name': tableName,
            'inputid': id,
            'inputdates': inputDateS,
            'inputdatee': inputDateE,
            'inputuser': inputUser,
          }
        },
      );

      final events = (response as List)
          .map((e) => EventItem.fromJson(json: e as Map<String, dynamic>))
          .toList()
          .map((e) {
        e.startDate = e.startDate?.toLocal();
        e.endDate = e.endDate?.toLocal();
        return e;
      }).toList();
      return events;
    } catch (ex, st) {
      logger.e(ex, stackTrace: st);
      rethrow;
    }
  }

  // 💾 儲存（新增或更新）事件 + 排程通知
  Future<void> saveEvent(
      {required String currentAccount,
      required EventItem event,
      required bool isNew,
      required String tableName}) async {
    try {
      _validateEvent(event: event);
      if (tableName == TableNames.recommendEvents) {
        event.city = EventCityNormalizer.normalize(event.city);
        for (final subEvent in event.subEvents) {
          subEvent.city = EventCityNormalizer.normalize(subEvent.city);
        }
      }
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
      //final Map<String, dynamic> data = event.toJson();
      if (isNew) {
        await supabase.from(tableName).insert([
          event.toJson(),
        ]);
      } else {
        final data = event.toJson();
        var query = supabase
            .from(tableName)
            .update(data)
            .eq(Fields.id, data[Fields.id]);

        // 非系統管理員只能更新自己的事件
        if (!_isCurrentUserAdmin && data[Fields.account] != null) {
          query = query.eq(Fields.account, data[Fields.account]);
        }

        await query;
      }
    } on PostgrestException catch (ex, stacktrace) {
      logger.e("saveEvent error", error: ex, stackTrace: stacktrace);
      if (ex.code == '23505') {
        throw const EventSaveException(EventSaveError.duplicate);
      }
      rethrow;
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
      final data = event.toJson();
      if (tableName == TableNames.recommendEvents) {
        await supabase.from(TableNames.recommendEventsDeleted).insert([data]);
      }

      var query =
          supabase.from(tableName).delete().eq(Fields.id, data[Fields.id]);

      // 非系統管理員只能刪自己的事件
      if (!_isCurrentUserAdmin) {
        query = query.eq(
          Fields.account,
          currentAccount,
        );
      }

      final result = await query.select();

      if (result.isEmpty) {
        throw Exception("event not found");
      }
    } catch (ex, stacktrace) {
      logger.e("deleteEvent error", error: ex, stackTrace: stacktrace);
      rethrow;
    }
  }

  // ✅ 核准事件 (由管理者)
  Future<void> approvalEvent(
      {required EventItem event, required String tableName}) async {
    final data = event.toJson();
    var query =
        supabase.from(tableName).update(data).eq(Fields.id, data[Fields.id]);

    await query;
  }

  Future<void> updateLikeEvent(
      {required EventItem event, required String account}) async {
    final Map<String, dynamic> data = {
      "id": event.id,
      "is_like": event.isLike,
      "is_dislike": event.isDislike,
      "account": account
    };
    try {
      await supabase.from(TableNames.recommendEventsFavor).insert([data]);
    } catch (ex) {
      try {
        var query = supabase
            .from(TableNames.recommendEventsFavor)
            .update(data)
            .eq(Fields.id, data[Fields.id]);

        await query;
      } catch (ex) {
        logger.e(ex);
      }
    }
  }

  // --- 私有方法 ---
  void _validateEvent({required EventItem event}) {
    if (event.name.isEmpty) {
      throw const EventSaveException(EventSaveError.missingName);
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

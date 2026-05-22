import 'package:flutter/material.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceEvent {
  final client = Supabase.instance.client;
  ServiceEvent();

  Future<String> getKey({required String keyName}) async {
    try {
      //final response = await api.post('event/get_api_key', {'p_key_name': keyName});
      final response =
          await apiSupabase.post('event/get_api_key', {'p_key_name': keyName});
      return response['value'];
    } catch (e) {
      logger.e('Error fetching key: $e');
      return '';
    }
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
    final cutoffDate = today.subtract(Duration(days: 2));
    if (tableName == TableNames.recommendedEvents && today.weekday == 3) {
      try {
        //await 
        api.post('event/cleanup_recommended_events',
            {'cutoff': cutoffDate.toIso8601String()});
      } on Exception catch (ex) {
        logger.e(ex);
      }

      await apiSupabase.post('event/cleanup_recommended_events',
          {'cutoff': cutoffDate.toIso8601String()});
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
      /*
      final response = await api.post('event/get_filtered', {
        'table_name': tableName,
        'inputid': id,
        'inputdates': inputDateS,
        'inputdatee': inputDateE,
        'inputuser': inputUser,
      });
      */
      final response = await apiSupabase.post('event/get_filtered', {
        'table_name': tableName,
        'inputid': id,
        'inputdates': inputDateS,
        'inputdatee': inputDateE,
        'inputuser': inputUser,
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
        try {
          //await 
          api.post('event/insert', {
            'table_name': tableName,
            'events': [event.toJson()],
          });
        } on Exception catch (ex) {
          logger.e(ex);
        }
        await apiSupabase.post('event/insert', {
          'table_name': tableName,
          'events': [event.toJson()],
        });
      } else {
        try {
          //await 
          api.post('event/update', {
            'table_name': tableName,
            'current_account': currentAccount,
            'event': event.toJson(),
          });
        } on Exception catch (ex) {
          logger.e(ex);
        }
        await apiSupabase.post('event/update', {
          'table_name': tableName,
          'current_account': currentAccount,
          'event': event.toJson(),
        });
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
      if (tableName == TableNames.recommendedEvents) {
        try {
          //await 
          api.post('event/insert', {
            'table_name': TableNames.recommendedEventsDeleted,
            'events': [event.toJson()],
          });
        } on Exception catch (ex) {
          logger.e(ex);
        }
        await apiSupabase.post('event/insert', {
          'table_name': TableNames.recommendedEventsDeleted,
          'events': [event.toJson()],
        });
      }
      try {
        //await 
        api.post('event/delete', {
          'table_name': tableName,
          'current_account': currentAccount,
          'event': event.toJson(),
        });
      } on Exception catch (ex) {
        logger.e(ex);
      }
      await apiSupabase.post('event/delete', {
        'table_name': tableName,
        'current_account': currentAccount,
        'event': event.toJson(),
      });
    } catch (ex, stacktrace) {
      logger.e("deleteEvent error", error: ex, stackTrace: stacktrace);
      rethrow;
    }
  }

  // ✅ 核准事件 (由管理者)
  Future<void> approvalEvent(
      {required EventItem event, required String tableName}) async {
    try {
      //await 
      api.post('event/update', {
        'table_name': tableName,
        'current_account': AuthConstants.sysAdminEmail,
        'event': event.toJson(),
      });
    } catch (ex, stacktrace) {
      logger.e("approvalEvent error", error: ex, stackTrace: stacktrace);
    }

    await apiSupabase.post('event/update', {
      'table_name': tableName,
      'current_account': AuthConstants.sysAdminEmail,
      'event': event.toJson(),
    });
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
      //await 
      api.post('event/insert', {
        'table_name': TableNames.recommendedEventsFavor,
        'events': [data],
      });
    } catch (ex) {
      try {
        //await 
        api.post('event/update', {
          'table_name': TableNames.recommendedEventsFavor,
          'event': data,
        });
      } catch (ex) {
        logger.e(ex);
      }
    }

    try {
      await apiSupabase.post('event/insert', {
        'table_name': TableNames.recommendedEventsFavor,
        'events': [data],
      });
    } catch (ex) {
      try {
        await apiSupabase.post('event/update', {
          'table_name': TableNames.recommendedEventsFavor,
          'event': data,
        });
      } catch (ex) {
        logger.e(ex);
      }
    }
  }

  Future<void> incrementEventCounter({
    required String? eventId,
    required String? eventName,
    required String column,
    required String account,
  }) async {
    try {
      //await 
      api.post('event/increment_event_counter', {
        'p_event_id': eventId,
        'p_event_name': eventName,
        'p_column': column,
        'p_account': account,
      });
    } catch (e) {
      logger.e('Error incrementEventCounter $column: $e');
    }

    try {
      await apiSupabase.post('event/increment_event_counter', {
        'p_event_id': eventId,
        'p_event_name': eventName,
        'p_column': column,
        'p_account': account,
      });
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

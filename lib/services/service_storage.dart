import 'package:flutter/material.dart' hide DateUtils;
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/notification/notification.dart';
import 'package:life_pilot/notification/notification_common.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceStorage {
  final _client = Supabase.instance.client;
  ServiceStorage();

  List<Event>? allEvents;

  Future<List<Event>?> getRecommendedEvents(
      {required String tableName,
      DateTime? dateS,
      DateTime? dateE,
      String? id}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final inputDateS =
        (dateS ?? today).formatDateString();
    final inputDateE =
        (dateE ?? DateTime(today.year + 2, today.month, today.day))
            .formatDateString();

    final response = await _client.rpc('get_filtered_$tableName', params: {
      'payload': {
        'inputid': id,
        'inputdates': inputDateS, // 傳 YYYY-MM-DD 格式給 SQL
        'inputdatee': inputDateE, // 傳 YYYY-MM-DD 格式給 SQL
      }
    });

    allEvents = (response as List)
        .map((e) => Event.fromJson(e as Map<String, dynamic>))
        .toList();
    return allEvents;
  }

  Future<void> saveRecommendedEvent(
      BuildContext context, Event event, bool isNew, String tableName) async {
    try {
      AppLocalizations loc = AppLocalizations.of(context)!;
      _validateEvent(event, loc);
      if (isNew) {
        event.reminderOptions = [
          ReminderOption.oneHour, // 事件開始前1小時
          ReminderOption.sameDay8am,
          ReminderOption.dayBefore8am // 前一天早上8點
        ];
      }

      _normalizeEventDates(event);
      _normalizeSubEventsDates(event.subEvents);

      final Map<String, dynamic> data = event.toJson();
      if (isNew) {
        await _client.from(tableName).insert([data]); //'recommended_events'
      } else {
        await _client.from(tableName).update(data).eq(EventFields.id, event.id);
      }
      // 🔥 加入通知邏輯
      await MyCustomNotification.cancelEventReminders(event); // 移除舊通知（根據 id）
      await checkExactAlarmPermission(context);
      await MyCustomNotification.scheduleEventReminders(loc, event, tableName); // 新的排程
    } catch (ex, stacktrace) {
      logger.e("saveRecommendedEvent error", error: ex, stackTrace: stacktrace);
      rethrow;
    }
  }

  Future<void> deleteRecommendedEvent(Event event, String tableName) async {
    try {
      await MyCustomNotification.cancelEventReminders(event); // 取消通知
      await _client
          .from(tableName)
          .delete()
          .eq(EventFields.id, event.id); //'recommended_events'
    } catch (ex, stacktrace) {
      logger.e("deleteRecommendedEvent error",
          error: ex, stackTrace: stacktrace);
      rethrow;
    }
  }

  // --- 私有方法 ---
  void _validateEvent(Event event, AppLocalizations loc) {
    if (event.name.isEmpty) {
      throw Exception(loc.event_save_error);
    }
  }

  void _normalizeEventDates(Event event) {
    if (event.endDate != null && !event.endDate!.isAfter(event.startDate!)) {
      event.endDate = null;
    }
    if ((event.endDate == null || event.endDate == event.startDate) &&
        event.endTime != null &&
        !event.endTime!.isAfter(event.startTime!)) {
      event.endTime = null;
    }
  }

  void _normalizeSubEventsDates(List<SubEventItem> subEvents) {
    for (final subEvent in subEvents) {
      if (subEvent.endDate != null &&
          !subEvent.endDate!.isAfter(subEvent.startDate!)) {
        subEvent.endDate = null;
      }
      if ((subEvent.endDate == null ||
              subEvent.endDate == subEvent.startDate) &&
          subEvent.endTime != null &&
          !subEvent.endTime!.isAfter(subEvent.startTime!)) {
        subEvent.endTime = null;
      }
    }
  }
}

import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/models/model_event_fields.dart';
import 'package:life_pilot/models/model_event_sub_item.dart';
import 'package:life_pilot/notification/notification_entry.dart';
import 'package:life_pilot/notification/core/reminder_option.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/utils_date_time.dart'
    show DateTimeExtension, DateUtils;
import 'package:life_pilot/utils/core/utils_enum.dart';
import 'package:life_pilot/utils/platform/utils_mobile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceStorage {
  final _client = Supabase.instance.client;

  List<Event>? allEvents;

  // 📌 取得推薦事件 (由 Supabase 的 RPC 呼叫)
  Future<List<Event>?> getEvents({
    required String tableName,
    DateTime? dateS,
    DateTime? dateE,
    String? id,
    String? inputUser,
  }) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final inputDateS = (dateS ??
            (tableName == constTableMemoryTrace
                ? today.subtract(Duration(days: 365))
                : today))
        .formatDateString();
    final inputDateE =
        (dateE ?? DateTime(today.year + 2, today.month, today.day))
            .formatDateString();

    final response = await _client.rpc('get_filtered_$tableName', params: {
      'payload': {
        'inputid': id,
        'inputdates': inputDateS, // 傳 YYYY-MM-DD 格式給 SQL
        'inputdatee': inputDateE, // 傳 YYYY-MM-DD 格式給 SQL
        'inputuser': inputUser,
      }
    });

    allEvents = (response as List)
        .map((e) => Event.fromJson(e as Map<String, dynamic>))
        .toList();
    return allEvents;
  }

  // ✅ 核准事件 (由管理者)
  Future<void> approvalEvent(
      {required Event event, required String tableName}) async {
    try {
      String? realAccount = event.account;
      if (event.account == constGuest) {
        event.account = constSysAdminEmail;
      }
      final Map<String, dynamic> data = event.toJson();
      var query =
          _client.from(tableName).update(data).eq(EventFields.id, event.id);
      if (realAccount != null &&
          realAccount.isNotEmpty &&
          realAccount != constGuest) {
        query = query.eq(EventFields.account, event.account!); // ✅ 明確保證非 null
      }
      await query;
    } catch (ex, stacktrace) {
      logger.e("approvalEvent error",
          error: ex, stackTrace: stacktrace);
      rethrow;
    }
  }

  // 💾 儲存（新增或更新）事件 + 排程通知
  Future<void> saveEvent(
      {required Event event,
      required bool isNew,
      required String tableName,
      required AppLocalizations loc}) async {
    try {
      ControllerAuth auth = getIt<ControllerAuth>();
      _validateEvent(event, loc);
      if ((isNew || event.reminderOptions.isEmpty) &&
          tableName == constTableCalendarEvents) {
        event.reminderOptions = [
          ReminderOption.oneHour, // 事件開始前1小時
          ReminderOption.sameDay8am,
          ReminderOption.dayBefore8am // 前一天早上8點
        ];
      }

      if (event.repeatOptions.key().isEmpty) {
        event.repeatOptions = RepeatRule.once;
      }

      _normalizeEventDates(event);
      _normalizeSubEventsDates(event.subEvents);
      event.account = auth.currentAccount;
      event.isApproved = false;
      final Map<String, dynamic> data = event.toJson();
      if (isNew) {
        await _client.from(tableName).insert([data]); //'recommended_events'
      } else {
        var query =
            _client.from(tableName).update(data).eq(EventFields.id, event.id);
        if (auth.currentAccount != constSysAdminEmail &&
            event.account != null &&
            event.account!.isNotEmpty) {
          query = query.eq(EventFields.account, event.account!); // ✅ 明確保證非 null
        }
        await query;
      }

      // 🔥 加入通知邏輯
      if (tableName != constTableCalendarEvents) {
        return;
      }
      await NotificationEntryImpl.cancelEventReminders(
          event: event); // 移除舊通知（根據 id）
      await checkExactAlarmPermission();
      await NotificationEntryImpl.scheduleEventReminders(
          event: event, tableName: tableName, loc: loc); // 新的排程
    } catch (ex, stacktrace) {
      logger.e("saveEvent error", error: ex, stackTrace: stacktrace);
      rethrow;
    }
  }

  // ❌ 刪除推薦事件
  Future<void> deleteEvent(
      {required Event event, required String tableName}) async {
    try {
      ControllerAuth auth = getIt<ControllerAuth>();
      await NotificationEntryImpl.cancelEventReminders(event: event); // 取消通知
      var query = _client.from(tableName).delete().eq(EventFields.id, event.id);
      if (auth.currentAccount != constSysAdminEmail &&
          event.account != null &&
          event.account!.isNotEmpty) {
        query = query.eq(EventFields.account, event.account!);
      }
      await query;
    } catch (ex, stacktrace) {
      logger.e("deleteEvent error",
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

  void _normalizeSubEventsDates(List<EventSubItem> subEvents) {
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

import 'dart:async';
import 'package:life_pilot/core/calendar/utils_calendar.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/services/platforms/notification_util.dart';
import 'package:life_pilot/services/service_notification/service_notification_platform.dart';

class ControllerNotification {
  final ServiceNotificationPlatform service;

  ControllerNotification({required this.service});

  Future<void> initialize() async {
    await service.initialize();
  }

  Future<void> scheduleEventReminders({required EventItem event}) async {
    await scheduleMultipleReminders(events: [event]);
  }

  // 批量事件排程提醒（效能優化）
  Future<void> scheduleMultipleReminders({
    required List<EventItem> events,
  }) async {
    final futures = events.map((e) => service.scheduleEventReminders(event: e)).toList();
    await Future.wait(futures);
  }

  // 取消事件提醒
  Future<void> cancelEventReminders({required String eventId, required List<ReminderOption> reminderOptions}) async {
    await service.cancelEventReminders(eventId: eventId, reminderOptions: reminderOptions);
  }

  // 顯示今日事件通知，先在 Controller 過濾，提高效能
  Future<List<EventNotification>> showTodayEvents({
    required List<EventItem> events,
    required String closeText,
  }) async {
    final newEvents = getTodayEventNotificationsList(events: events);
    return newEvents.isNotEmpty ? await service.getTodayEventNotifications(
        events: newEvents, close: closeText) : [];
  }
}

/*批量處理：scheduleMultipleReminders 可同時排多個提醒。
簡化 async/await：initialize 不多餘的 await。
統一單一事件排程，方便批量方法呼叫。*/

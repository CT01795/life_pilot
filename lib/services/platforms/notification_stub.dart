import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:life_pilot/core/calendar/utils_calendar.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/services/service_notification/service_notification_platform.dart';

class NotificationServiceStub implements ServiceNotificationPlatform {
  
  @override
  FlutterLocalNotificationsPlugin? get plugin => null;
  
  @override
  Future<void> initialize() async {}

  // 根據 event.reminderOptions 安排通知
  @override
  Future<NotificationResult> scheduleEventReminders({
    required EventItem event
  }) async {
    return NotificationResult(success: false, message: constEmpty);
  }

  // 取消與此事件相關的所有提醒通知
  @override
  Future<void> cancelEventReminders({required String eventId, required List<ReminderOption> reminderOptions}) async {}

  @override
  Future<List<EventNotification>> getTodayEventNotifications(
      {required List<EventItem> events,
      required String close}) async {
    return [];
  }
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/service/service_notification/service_notification_platform.dart';

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
    return NotificationResult(success: false, message: '');
  }

  // 取消與此事件相關的所有提醒通知
  @override
  Future<void> cancelEventReminders({required String eventId, required List<CalendarReminderOption> reminderOptions}) async {}

  @override
  Future<List<EventNotification>> getTodayEventNotifications(
      {required List<EventItem> events,
      required String close}) async {
    return [];
  }
}

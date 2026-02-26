import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/enum.dart';

// 抽象通知服務：統一 API，不同平台會有不同實作
abstract class ServiceNotificationPlatform {

  FlutterLocalNotificationsPlugin? get plugin;

  Future<void> initialize();

  Future<NotificationResult> scheduleEventReminders({
    required EventItem event
  });

  Future<void> cancelEventReminders({
    required String eventId, required List<CalendarReminderOption> reminderOptions
  });

  Future<List<EventNotification>> getTodayEventNotifications({
    required List<EventItem> events,
    required String close,
  });
}

// 通知資料物件
class EventNotification {
  final int? id;
  final String title;
  final String body;
  final NotificationDetails? details;
  final String? payload;
  final String? message;

  EventNotification({
    this.id,
    required this.title,
    required this.body,
    this.details,
    this.payload,
    this.message,
  });
}

// 操作結果
class NotificationResult {
  final bool success;
  final String? message;

  NotificationResult({required this.success, this.message});
}

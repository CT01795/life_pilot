import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:life_pilot/app/config_app.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/service/service_notification/service_notification_platform.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationServiceWeb implements ServiceNotificationPlatform {
  @override
  FlutterLocalNotificationsPlugin? get plugin => null;

  @override
  Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(CalendarConfig.tzLocation));
  }

  // 根據 event.reminderOptions 安排通知
  @override
  Future<NotificationResult> scheduleEventReminders(
      {required EventItem event}) async {
    return NotificationResult(success: false, message: '');
  }

  // 取消與此事件相關的所有提醒通知
  @override
  Future<void> cancelEventReminders(
      {required String eventId,
      required List<CalendarReminderOption> reminderOptions}) async {}

  @override
  Future<List<EventNotification>> getTodayEventNotifications(
      {required List<EventItem> events, required String close}) async {
    if (events.isEmpty) return [];

    List<EventNotification> returnList = [];
    try {
      final now = DateTime.now().subtract(Duration(hours: 1));
      String title = '\t\t\t\t\t\t\t\tReminder:';
      final body = events
          .map((e) =>
              '${!DateTimeCompare.isSameDayFutureTime(e.startDate, e.startTime, now) ? 
                (!((e.endDate != null && DateTimeCompare.isSameDayFutureTime(e.endDate, e.endTime, now)) 
                  || (e.endDate == null && e.endTime != null && DateTimeCompare.isSameDayFutureTime(e.startDate, e.endTime, now))) ? 
                  now.formatDateString(passYear: true, formatShow: true) 
                  : '${e.endDate == null ? e.startDate!.formatDateString(passYear: true, formatShow: true) : e.endDate!.formatDateString(passYear: true, formatShow: true)} ${e.startTime!.formatTimeString()}') 
                : '${e.startDate!.formatDateString(passYear: true, formatShow: true)} ${e.startTime!.formatTimeString()}'} ${e.name}')
          .join('\n');
      returnList
          .add(EventNotification(title: title, body: body, message: close));
      return returnList;
    } catch (e) {
      logger.e('Failed to open exact alarm settings: ${e.toString()}');
      return [];
    }
  }
}

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:life_pilot/config/config_app.dart';
import 'package:life_pilot/core/calendar/utils_calendar.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/services/calendar/service_reminder.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/date_time.dart'
    show DateTimeCompare, DateTimeExtension, DateUtils, TimeOfDayExtension;
import 'package:life_pilot/services/service_notification/service_notification_platform.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationServiceMobile implements ServiceNotificationPlatform {
  final _plugin = FlutterLocalNotificationsPlugin();

  @override
  FlutterLocalNotificationsPlugin? get plugin => _plugin;

  @override
  Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(CalendarConfig.tzLocation));

    const android = AndroidInitializationSettings(CalendarMisc.androidIcon);
    const ios = DarwinInitializationSettings();
    await _plugin
        .initialize(InitializationSettings(android: android, iOS: ios));
    await _requestPermissions();
  }

  static Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // ✅ Android 13+ 通知權限請求
      if (!await Permission.notification.isGranted) {
        await Permission.notification.request();
      }

      final androidInfo = await DeviceInfoPlugin().androidInfo;
      // ✅ 檢查 Android 12+ 是否有精準鬧鐘權限
      if (androidInfo.version.sdkInt >= 31 &&
          !await Permission.scheduleExactAlarm.isGranted) {
        await openAppSettings(); // 引導設定
      }
    }

    /*if (Platform.isIOS) {
      // ✅ iOS 通知權限請求
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    }*/
  }

  // 根據 event.reminderOptions 安排通知
  @override
  Future<NotificationResult> scheduleEventReminders(
      {required EventItem event}) async {
    try {
      if (event.startDate == null || event.startTime == null) {
        return NotificationResult(success: false, message: constEmpty);
      }

      DateTime targetDT =
          DateUtils.getDateTime(event.startDate, event.startTime);
      final now = DateTime.now().subtract(Duration(hours: 1));
      for (final option in event.reminderOptions) {
        final reminderTime = ServiceReminder.getReminderTime(
            reminderOption: option, event: event, targetTime: targetDT);

        if (reminderTime.isBefore(now)) {
          // 避免過去的通知
          continue;
        }

        final id = ServiceReminder.generateNotificationId(
            eventId: event.id, reminderOption: option);
        final title =
            '**: ${event.startDate!.formatDateString(passYear: true, formatShow: true)} ${event.startTime?.formatTimeString()} ${event.name}';

        if (Platform.isAndroid) {
          final details = AndroidNotificationDetails(
            'event_channel', 
            constEmpty,
            channelDescription: constEmpty,
            importance: Importance.high,
            priority: Priority.high,
            ticker: 'ticker',
          );
          await _plugin.zonedSchedule(
            id,
            title,
            constEmpty,
            tz.TZDateTime.from(reminderTime, tz.local),
            NotificationDetails(android: details),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
      return NotificationResult(success: true, message: constEmpty);
    } catch (e) {
      return NotificationResult(success: false, message: e.toString());
    }
  }

  Future<EventNotification> _showImmediateNotification(
      {required EventItem event,
      required DateTime now}) async {
    // 通知ID，建議用事件ID或其它唯一數字
    final int notificationId = ServiceReminder.generateNotificationId(
        eventId: event.id, reminderOption: ReminderOption.fifteenMin);
    // 通知標題
    final String title =
        '${!DateTimeCompare.isSameDayFutureTime(event.startDate, event.startTime, now) ? 
                (!((event.endDate != null && DateTimeCompare.isSameDayFutureTime(event.endDate, event.endTime, now)) 
                  || (event.endDate == null && event.endTime != null && DateTimeCompare.isSameDayFutureTime(event.startDate, event.endTime, now))) ? 
                  now.formatDateString(passYear: true, formatShow: true) 
                  : '${event.endDate == null ? event.startDate!.formatDateString(passYear: true, formatShow: true) : event.endDate!.formatDateString(passYear: true, formatShow: true)} ${event.startTime!.formatTimeString()}') 
                : '${event.startDate!.formatDateString(passYear: true, formatShow: true)} ${event.startTime!.formatTimeString()}'} ${event.name}';
    // 通知內容
    final String body = constEmpty;

    final details = AndroidNotificationDetails(
      'immediate_event_channel',
      'Event Notifications',
      channelDescription: 'Upcoming...',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
    );

    return EventNotification(
      id: notificationId,
      title: title,
      body: body,
      details: NotificationDetails(android: details),
      payload: event.id.toString(),
    );
  }

  // 取消與此事件相關的所有提醒通知
  @override
  Future<NotificationResult> cancelEventReminders(
      {required String eventId, required List<ReminderOption> reminderOptions}) async {
    try {
      for (final option in reminderOptions) {
        await _plugin.cancel(ServiceReminder.generateNotificationId(
            eventId: eventId, reminderOption: option));
      }
      return NotificationResult(success: true);
    } catch (e) {
      return NotificationResult(success: false, message: e.toString());
    }
  }

  @override
  Future<List<EventNotification>> getTodayEventNotifications({
    required List<EventItem> events,
    required String close,
  }) async {
    if (events.isEmpty) return [];

    List<EventNotification> returnList = [];
    final now = DateTime.now().subtract(Duration(hours: 1));
    for (final event in events) {
      returnList.add(
          await _showImmediateNotification(event: event, now: now));
    }
    return returnList;
  }
}

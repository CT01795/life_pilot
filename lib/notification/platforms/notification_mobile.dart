import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event_item.dart';
import 'package:life_pilot/notification/core/reminder_option.dart';
import 'package:life_pilot/notification/core/reminder_utils.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/utils_date_time.dart'
    show DateUtils, DateTimeExtension, TimeOfDayExtension;
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationEntryImpl {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // 初始化通知（應在 main.dart 呼叫）
  static Future<void> initialize() async {
    // ✅ Android 13+ 通知權限請求
    await _requestPermissions();
    await _initializePlugin();
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(constTzLocation));
  }

  // 根據 event.reminderOptions 安排通知
  static Future<void> scheduleEventReminders(
      {required EventItem event,
      required String tableName,
      required AppLocalizations loc}) async {
    if (event.startDate == null || event.startTime == null) {
      return;
    }

    DateTime targetDT = DateUtils.getDateTime(event.startDate, event.startTime);
    for (final option in event.reminderOptions) {
      final reminderTime = _calculateReminderTime(option, event, targetDT);
      if (reminderTime.isBefore(DateTime.now())) {
        // 避免過去的通知
        continue;
      }

      final id = ReminderUtils.generateNotificationId(
          eventId: event.id, optionKey: option.toKey());
      final title =
          '${loc.event_reminder}: ${event.startDate!.formatDateString(passYear: true, formatShow: true)} ${event.startTime?.formatTimeString()} ${event.name}';
      final body =
          ReminderUtils.getReminderLabel(loc: loc, reminderOption: option);

      if (Platform.isAndroid) {
        final details = _buildAndroidNotificationDetails(
            channelId: 'event_channel',
            channelName: loc.event_reminder_desc,
            description: body);
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(reminderTime, tz.local),
          NotificationDetails(android: details),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }

  static Future<void> showTodayEventsWebNotification(
      {required String tableName, required AppLocalizations loc}) async {
    // 空實作，避免編譯錯誤
    return;
  }

  static Future<void> showImmediateNotification(
      {required EventItem event, required AppLocalizations loc}) async {
    // 通知ID，建議用事件ID或其它唯一數字
    final int notificationId = ReminderUtils.generateNotificationId(
        eventId: event.id, optionKey: 'immediate');

    // 通知標題
    final String title =
        '${loc.event_reminder_today} ${event.startTime == null ? constEmpty : event.startTime?.formatTimeString()} ${event.name}';
    // 通知內容
    final String body = constEmpty;

    final details = _buildAndroidNotificationDetails(
        channelId: 'immediate_event_channel',
        channelName: 'Event Notifications',
        description: loc.event_reminder_desc);

    // 直接立即顯示通知
    await _plugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(android: details),
      payload: event.id.toString(), // 可帶參數，點通知時用
    );
  }

  // 取消與此事件相關的所有提醒通知
  static Future<void> cancelEventReminders({required EventItem event}) async {
    for (final option in event.reminderOptions) {
      await _plugin.cancel(ReminderUtils.generateNotificationId(
          eventId: event.id, optionKey: option.toKey()));
    }
  }

  static void showNotificationWeb(
      {required String title, required String body, required String tooltip}) {}

  // --- 私有方法 ---
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

    if (Platform.isIOS) {
      // ✅ iOS 通知權限請求
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  static Future<void> _initializePlugin() async {
    const android = AndroidInitializationSettings(constAndroidIcon);
    const ios = DarwinInitializationSettings();
    await _plugin
        .initialize(InitializationSettings(android: android, iOS: ios));
  }

  static AndroidNotificationDetails _buildAndroidNotificationDetails(
      {required String channelId,
      required String channelName,
      String? description}) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: description,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
    );
  }

  static DateTime _calculateReminderTime(
      ReminderOption option, EventItem event, DateTime targetTime) {
    switch (option) {
      case ReminderOption.sameDay8am:
        return DateUtils.getDateTime(
            event.startDate, TimeOfDay(hour: 8, minute: 0));
      case ReminderOption.dayBefore8am:
        return DateUtils.getDateTime(
            event.startDate!.subtract(Duration(days: 1)),
            TimeOfDay(hour: 8, minute: 0));
      default:
        return targetTime.subtract(ReminderUtils.getReminderDuration(option));
    }
  }
}
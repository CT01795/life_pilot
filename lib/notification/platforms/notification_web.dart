import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: deprecated_member_use
import 'package:js/js.dart';
// ignore: deprecated_member_use
import 'package:js/js_util.dart' as js_util;
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/notification/core/notification_overlay.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/utils_date_time.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

@anonymous
@JS()
class NotificationOptions {
  external String? get body;

  external factory NotificationOptions({String? body});
}

class JsNotificationStatic {
  static String? get permission {
    final value = js_util.getProperty(js_util.globalThis, 'Notification');
    if (value == null) return null;

    final permission = js_util.getProperty(value, 'permission');
    return permission is String ? permission : null;
  }

  static Future<String?> requestPermission() async {
    final notif = js_util.getProperty(js_util.globalThis, 'Notification');
    if (notif == null) return null;
    final promise = js_util.callMethod(notif, 'requestPermission', []);
    final result = await js_util.promiseToFuture(promise);
    return result is String ? result : null;
  }

  static bool get supported =>
      js_util.hasProperty(js_util.globalThis, 'Notification');
}

class NotificationEntryImpl {
  // 初始化通知（應在 main.dart 呼叫）
  static Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(constTzLocation));
  }

  // 根據 event.reminderOptions 安排通知
  static Future<void> scheduleEventReminders({
    required Event event,
    required String tableName,
    required AppLocalizations loc,
  }) async {
    if (event.startDate == null || event.startTime == null) {
      return;
    }

    if (kIsWeb) {
      showTodayEventsWebNotification(tableName: tableName, loc: loc);
      return; // Web 單次執行完畢，結束方法
    }
  }

  static Future<void> showTodayEventsWebNotification(
      {required String tableName, required AppLocalizations loc}) async {
    if (tableName != constTableCalendarEvents) {
      //如果不是行事曆的事件就不要通知
      return;
    }

    ControllerAuth auth = getIt<ControllerAuth>();
    ServiceStorage service = getIt<ServiceStorage>();
    final user = auth.currentAccount;
    // 取得現在時間
    final now = DateTime.now();
    List<Event>? todayEvents = await service.getEvents(
        tableName: tableName, dateS: now, dateE: now, inputUser: user);

    if (todayEvents == null || todayEvents.isEmpty) return;

    // 過濾出尚未發生的事件
    todayEvents = todayEvents.where((e) {
      if (e.startDate == null) return false;
      if (e.startTime == null) return true;
      // 將日期跟時間組合成完整 DateTime
      final eventDateTime = DateTime(
        e.startDate!.year,
        e.startDate!.month,
        e.startDate!.day,
        e.startTime!.hour,
        e.startTime!.minute,
      );
      // 只挑出事件開始時間晚於現在的事件
      return eventDateTime.isAfter(now.subtract(Duration(hours: 1)));
    }).toList();

    if (todayEvents.isEmpty) return;

    try {
      String title = '\t\t\t\t\t\t\t\t${loc.event_reminder}:';
      final body = todayEvents
          .map((e) =>
              '${e.startDate?.formatDateString(passYear: true, formatShow: true)} ${e.startTime?.formatTimeString()} ${e.name}')
          .join('\n');
      Timer(
          Duration(seconds: 1),
          () => showNotificationWeb(
              title: title, body: body, tooltip: loc.close));
      logger.d("Notification permission granted.");
    } catch (e) {
      logger.e('Failed to open exact alarm settings: ${e.toString()}');
    }
  }

  static Future<void> showImmediateNotification(
      {required Event event, required AppLocalizations loc}) async {
    // 空實作，避免編譯錯誤
    return;
  }

  // 取消與此事件相關的所有提醒通知
  static Future<void> cancelEventReminders({required Event event}) async {
    // 空實作，避免編譯錯誤
  }

  // 在這裡提供開通知的方法，用 new Notification(...) 形式
  static void showNotificationWeb(
      {required String title, required String body, required String tooltip}) {
    if (!JsNotificationStatic.supported) return;

    // 如果沒權限，就先要求
    final perm = JsNotificationStatic.permission;
    if (perm != 'granted') {
      JsNotificationStatic.requestPermission().then((p) {
        if (p == 'granted') {
          showWebOverlay(
              title: title, body: body, tooltip: tooltip);
        } else {
          // 權限被拒，或使用者沒回應
          logger.w('Notification permission denied or not granted');
        }
      });
    } else {
      showWebOverlay(
          title: title, body: body, tooltip: tooltip);
    }
  }
}

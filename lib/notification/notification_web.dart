// ignore: deprecated_member_use
import 'package:js/js.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide DateUtils;
// ignore: deprecated_member_use
import 'package:js/js_util.dart' as js_util;
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/notification/notification_common.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:life_pilot/utils/utils_date_time.dart';
import 'package:provider/provider.dart';
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

// 在這裡提供開通知的方法，用 new Notification(...) 形式
void showWebNotification(String title, String? body, String tooltip) {
  if (!JsNotificationStatic.supported) return;

  // 如果沒權限，就先要求
  final perm = JsNotificationStatic.permission;
  if (perm != 'granted') {
    JsNotificationStatic.requestPermission().then((p) {
      if (p == 'granted') {
        MyCustomNotification.showMyCustomNotification(
            title, body ?? constEmpty, tooltip);
      } else {
        // 權限被拒，或使用者沒回應
        logger.w('Notification permission denied or not granted');
      }
    });
  } else {
    MyCustomNotification.showMyCustomNotification(
        title, body ?? constEmpty, tooltip);
  }
}

class MyCustomNotification {
  // 初始化通知（應在 main.dart 呼叫）
  static Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(constTzLocation));
  }

  // 根據 event.reminderOptions 安排通知
  static Future<void> scheduleEventReminders(Event event, String tableName,
      {required BuildContext context}) async {
    if (event.startDate == null || event.startTime == null) {
      return;
    }

    if (kIsWeb) {
      showTodayEventsWebNotification(tableName, context: context);
      return; // Web 單次執行完畢，結束方法
    }
  }

  static Future<void> showTodayEventsWebNotification(String tableName,
      {required BuildContext context}) async {
    if (tableName != constTableCalendarEvents) {
      //如果不是行事曆的事件就不要通知
      return;
    }

    final auth = Provider.of<ControllerAuth>(context, listen: false);
    final loc = AppLocalizations.of(context)!;
    final service = Provider.of<ServiceStorage>(context, listen: false);
    final user = auth.currentAccount;
    // 取得現在時間
    final now = DateTime.now();
    List<Event>? todayEvents = await service.getRecommendedEvents(
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
      return eventDateTime.isAfter(now.subtract(Duration(hours:1)));
    }).toList();

    if (todayEvents.isEmpty) return;

    try {
      String title = '\t\t\t\t\t\t\t\t${loc.event_reminder}:';
      final body = todayEvents
          .map((e) =>
              '${e.startDate!.formatDateString(passYear: true, formatShow: true)} ${e.startTime!.formatTimeString()} ${e.name}')
          .join('\n');
      Timer(Duration(seconds: 1),
          () => showWebNotification(title, body, loc.close));
      logger.d("Notification permission granted.");
    } catch (e) {
      logger.e('Failed to open exact alarm settings: ${e.toString()}');
    }
  }

  static Future<void> showImmediateNotification(Event event,
      {required BuildContext context}) async {
    // 空實作，避免編譯錯誤
    return;
  }

  // 取消與此事件相關的所有提醒通知
  static Future<void> cancelEventReminders(Event event) async {
    // 空實作，避免編譯錯誤
  }

  static void showMyCustomNotification(
      String title, String body, String toolTip) {
    final overlay = currentOverlay;
    if (overlay == null) {
      logger.w("No overlay available");
      return;
    }

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => PositionedDirectional(
        end: 20, // Directional 替代 right
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: kGapEI12,
            color: Colors.white,
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    kGapH4(),
                    Text(
                        body), //, style: TextStyle(fontWeight: FontWeight.bold)
                  ],
                ),
                Positioned(
                  child: GestureDetector(
                    onTap: () {
                      overlayEntry.remove();
                    },
                    child: Tooltip(
                      message: toolTip, // 這是你要顯示的提示文字
                      child: Container(
                        padding: kGapEIR3,
                        child: Icon(Icons.info_rounded),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(Duration(seconds: 10), () {
      if (overlayEntry.mounted) {
        try {
          overlayEntry.remove();
        } catch (e) {
          logger.e('Failed to remove overlayEntry: $e');
        }
      } else {
        logger.w('OverlayEntry already removed or unmounted.');
      }
    });
  }
}

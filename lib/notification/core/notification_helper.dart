import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:life_pilot/controllers/controller_calendar.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:life_pilot/utils/utils_date_time.dart';

import '../notification_entry.dart';

class NotificationHelper {
  static Future<void> notifyTodayEvents({required AppLocalizations loc}) async {
    ControllerCalendar controller = getIt<ControllerCalendar>();
    if (kIsWeb) {
      NotificationEntryImpl.showTodayEventsWebNotification(
          tableName: controller.tableName, loc: loc);
    } else if (Platform.isAndroid) {
      // 從 _controller 拿今天的事件清單
      final today = DateTime.now();
      final todayDateOnly = DateUtils.dateOnly(today);
      final todayEvents = controller.events;

      for (final event in todayEvents) {
        final end = event.endDate ?? event.startDate;
        if (DateTimeCompare.isSameDayFutureTime(
                event.startDate, event.startTime, today) ||
            DateTimeCompare.isSameDayFutureTime(end, event.endTime, today) ||
            (event.startDate != null &&
                event.startDate!.isBefore(todayDateOnly) &&
                end != null &&
                end.isAfter(todayDateOnly))) {
          await NotificationEntryImpl.showImmediateNotification(
              event: event, loc: loc);
        }
      }
    }
  }
}

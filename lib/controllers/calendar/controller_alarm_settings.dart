import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/calendar/controller_calendar.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/logger.dart';
import 'package:life_pilot/core/calendar/utils_calendar.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/services/event/service_event.dart';

class ControllerAlarmSettings {
  final ControllerCalendar controllerCalendar;
  final ServiceEvent serviceEvent;

  ControllerAlarmSettings({
    required this.controllerCalendar,
    required this.serviceEvent,
  });

  /// ✅ 儲存提醒設定（含通知與重複事件處理）
  Future<String> saveSettings({
    required ControllerAuth auth,
    required EventItem event,
    required RepeatRule repeat,
    required List<ReminderOption> reminders,
  }) async {
    try {
      // 更新事件資料
      final updatedEvent = event.copyWith(
        newReminderOptions: reminders,
        newRepeatOptions: repeat,
      );

      await controllerCalendar.controllerEvent.saveEventWithNotification(
        oldEvent: event,
        newEvent: updatedEvent,
        isNew: false,
      );

      // 重新載入事件
      await controllerCalendar.loadCalendarEvents(month: updatedEvent.startDate!);

      // 若為重複事件，自動生成下一次
      if (repeat.key.startsWith('every')) {
        await controllerCalendar.checkAndGenerateNextEvents();
      }
      logger.i('✅ Alarm settings saved successfully.');
      return constEmpty;
    } catch (e, st) {
      logger.e('❌ saveSettings error: $e', stackTrace: st);
      return '❌ error: ${e.toString()}';
    }
  }
}

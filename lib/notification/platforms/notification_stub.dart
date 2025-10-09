import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event_item.dart';

abstract class NotificationEntryImpl {
  static Future<void> initialize() async {}

  static Future<void> scheduleEventReminders({
    required EventItem event,
    required String tableName,
    required AppLocalizations loc
  }) async {}

  static Future<void> showTodayEventsWebNotification({
    required String tableName, required AppLocalizations loc
  }) async {}

  static Future<void> showImmediateNotification({
    required EventItem event,
    required AppLocalizations loc,
  }) async {}

  static Future<void> cancelEventReminders({required EventItem event}) async {}

  static void showNotificationWeb(
      {required String title, required String body, required String tooltip}) {}
}

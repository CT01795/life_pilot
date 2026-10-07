import 'package:flutter/material.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/widgets_schedule_datetime_dialog.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/subscription/widgets_subscription_usage.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/widgets/widgets_confirmation_dialog.dart';
import 'package:provider/provider.dart';

Future<ScheduleDateTimeChoice?> chooseRecommendationSchedule({
  required BuildContext context,
  required String title,
  DateTime? sourceDate,
  TimeOfDay? sourceTime,
  String? description,
}) {
  final now = DateTime.now();
  final initialDate = initialRecommendedScheduleDate(
    sourceDate: sourceDate,
    currentDateTime: now,
  );
  return showScheduleDateTimeDialog(
    context,
    title: title,
    description: description,
    initialDate: initialDate,
    initialTime: initialRecommendedScheduleTime(
      selectedDate: initialDate,
      sourceTime: sourceTime,
      currentDateTime: now,
    ),
  );
}

Future<bool> confirmRecommendationDuplicate({required AppLocalizations loc}) =>
    showConfirmationDialog(
      content: loc.scheduleDuplicateConfirmation,
      confirmText: loc.add,
      cancelText: loc.cancel,
    );

void publishAddedCalendarEvent({
  required BuildContext context,
  required CalendarEvent event,
  required String account,
  required AppLocalizations loc,
}) {
  context.read<ModelDashboard>().addUpcomingEvent(event, account: account);
  context.read<ControllerCalendar>().invalidateEventCache(
    startDate: event.startDate,
    endDate: event.endDate,
  );
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(loc.eventAddOk)));
}

void showRecommendationCalendarAddFailure({
  required BuildContext context,
  required AppLocalizations loc,
  required Object error,
  required StackTrace stackTrace,
  required String source,
}) {
  logger.e(
    'Could not add $source to calendar.',
    error: error,
    stackTrace: stackTrace,
  );
  if (!context.mounted) return;
  final quotaMessage = subscriptionErrorMessage(loc, error);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        quotaMessage.isNotEmpty ? quotaMessage : loc.eventSaveFailed,
      ),
    ),
  );
}

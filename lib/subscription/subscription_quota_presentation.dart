import 'package:intl/intl.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/subscription_constants.dart';

String formatSubscriptionNumber(
  AppLocalizations loc,
  num value, {
  int fractionDigits = 0,
}) => NumberFormat.decimalPatternDigits(
  locale: loc.localeName,
  decimalDigits: fractionDigits,
).format(value);

String subscriptionResourceLabel(AppLocalizations loc, String resource) =>
    switch (resource) {
      SubscriptionResource.calendarEvents => loc.personalEvent,
      SubscriptionResource.recommendedEvents => loc.activeEventSubmissions,
      SubscriptionResource.recommendedAttractions => loc.activePlaceSubmissions,
      SubscriptionResource.accountingDetail => loc.accountRecords,
      SubscriptionResource.pointRecordDetail => loc.pointsRecord,
      SubscriptionResource.memoryTrace => loc.memoryTrace,
      SubscriptionResource.gameQuestions => loc.game,
      SubscriptionResource.calendarShares => loc.calendarSharing,
      SubscriptionResource.imageBytes => loc.subscriptionImageStorage,
      _ => resource,
    };

String subscriptionQuotaValue(
  AppLocalizations loc,
  String resource,
  int value, {
  bool zeroMeansNotLimited = false,
}) {
  if (zeroMeansNotLimited && value == 0) return loc.quotaNotLimited;
  return resource == SubscriptionResource.imageBytes
      ? '${formatSubscriptionNumber(loc, value ~/ 1024 ~/ 1024)} MB'
      : formatSubscriptionNumber(loc, value);
}

bool localQuotaIsUnlimited(String resource, int value) =>
    value == 0 &&
    const {
      SubscriptionResource.calendarEvents,
      SubscriptionResource.accountingDetail,
      SubscriptionResource.pointRecordDetail,
      SubscriptionResource.memoryTrace,
      SubscriptionResource.gameQuestions,
    }.contains(resource);

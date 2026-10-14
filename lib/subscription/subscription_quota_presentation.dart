import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/subscription_constants.dart';

String subscriptionResourceLabel(AppLocalizations loc, String resource) =>
    switch (resource) {
      SubscriptionResource.calendarEvents => loc.personalEvent,
      SubscriptionResource.recommendedEvents => loc.recommendEvent,
      SubscriptionResource.recommendedAttractions => loc.recommendPlaces,
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
      ? '${value ~/ 1024 ~/ 1024} MB'
      : value.toString();
}

bool localQuotaIsUnlimited(String resource, int value) =>
    value == 0 &&
    resource != SubscriptionResource.recommendedEvents &&
    resource != SubscriptionResource.recommendedAttractions;

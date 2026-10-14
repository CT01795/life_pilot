abstract final class SubscriptionStoragePlan {
  static const cloud = 'cloud';
  static const local = 'local';

  static const values = <String>[cloud, local];
}

abstract final class SubscriptionResource {
  static const calendarEvents = 'calendar_events';
  static const recommendedEvents = 'recommended_events';
  static const recommendedAttractions = 'recommended_attractions';
  static const accountingDetail = 'accounting_detail';
  static const pointRecordDetail = 'point_record_detail';
  static const memoryTrace = 'memory_trace';
  static const gameQuestions = 'game_questions';
  static const calendarShares = 'calendar_shares';
  static const imageBytes = 'image_bytes';
  static const answerHistoryDays = 'answer_history_days';

  static const quotaResources = <String>[
    calendarEvents,
    recommendedEvents,
    recommendedAttractions,
    accountingDetail,
    pointRecordDetail,
    memoryTrace,
    gameQuestions,
    calendarShares,
    imageBytes,
    answerHistoryDays,
  ];

  static const visibleQuotaResources = <String>[
    calendarEvents,
    recommendedEvents,
    recommendedAttractions,
    accountingDetail,
    pointRecordDetail,
    memoryTrace,
    gameQuestions,
    calendarShares,
    imageBytes,
  ];
}

bool shouldShowSubscriptionResource(
  String resource, {
  required bool canUsePoints,
  required bool canUseGame,
}) =>
    (resource != SubscriptionResource.pointRecordDetail || canUsePoints) &&
    (resource != SubscriptionResource.gameQuestions || canUseGame);

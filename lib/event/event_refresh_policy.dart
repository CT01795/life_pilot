import 'package:flutter/foundation.dart';
import 'package:life_pilot/utils/const.dart';

class EventRefreshPolicy {
  const EventRefreshPolicy._();

  static bool canRefresh({
    required String tableName,
    required bool isAdmin,
    required bool isWeb,
    required TargetPlatform platform,
    required bool hasCheckedUpdate,
    required bool updatedToday,
    required bool isRunning,
  }) {
    if (tableName != TableNames.recommendEvents) return false;
    if (!hasCheckedUpdate || updatedToday || isRunning) return false;
    if (isAdmin) return true;

    final isMobileApp = !isWeb &&
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS);
    return isMobileApp;
  }
}

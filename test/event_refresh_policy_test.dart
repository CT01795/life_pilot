import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/event_refresh_policy.dart';
import 'package:life_pilot/utils/const.dart';

void main() {
  bool canRefresh({
    String tableName = TableNames.recommendEvents,
    bool isAdmin = false,
    bool isWeb = false,
    TargetPlatform platform = TargetPlatform.android,
    bool hasCheckedUpdate = true,
    bool updatedToday = false,
  }) =>
      EventRefreshPolicy.canRefresh(
        tableName: tableName,
        isAdmin: isAdmin,
        isWeb: isWeb,
        platform: platform,
        hasCheckedUpdate: hasCheckedUpdate,
        updatedToday: updatedToday,
      );

  test('admin can refresh recommended events on every platform', () {
    expect(
      canRefresh(
        isAdmin: true,
        isWeb: true,
        platform: TargetPlatform.windows,
        updatedToday: true,
      ),
      isTrue,
    );
  });

  test('mobile user can refresh after status check when not updated today', () {
    expect(canRefresh(), isTrue);
    expect(canRefresh(platform: TargetPlatform.iOS), isTrue);
  });

  test('mobile user cannot refresh when already updated today', () {
    expect(canRefresh(updatedToday: true), isFalse);
  });

  test('button stays hidden before update status check finishes', () {
    expect(canRefresh(hasCheckedUpdate: false), isFalse);
  });

  test('normal web and desktop users cannot trigger refresh', () {
    expect(canRefresh(isWeb: true), isFalse);
    expect(canRefresh(platform: TargetPlatform.windows), isFalse);
  });

  test('refresh is never available for a non-recommended-event table', () {
    expect(canRefresh(tableName: TableNames.calendarEvents), isFalse);
    expect(
      canRefresh(tableName: TableNames.calendarEvents, isAdmin: true),
      isFalse,
    );
  });
}

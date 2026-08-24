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
    bool isRunning = false,
  }) =>
      EventRefreshPolicy.canRefresh(
        tableName: tableName,
        isAdmin: isAdmin,
        isWeb: isWeb,
        platform: platform,
        hasCheckedUpdate: hasCheckedUpdate,
        updatedToday: updatedToday,
        isRunning: isRunning,
      );

  test('admin can refresh recommended events after status is checked', () {
    expect(
      canRefresh(
        isAdmin: true,
        isWeb: true,
        platform: TargetPlatform.windows,
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

  test('admin and mobile user cannot refresh while another update runs', () {
    expect(canRefresh(isRunning: true), isFalse);
    expect(canRefresh(isAdmin: true, isRunning: true), isFalse);
  });

  test('admin cannot refresh when already updated today', () {
    expect(canRefresh(isAdmin: true, updatedToday: true), isFalse);
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/controller_notification.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/calendar/model_calendar_month_query.dart';
import 'package:life_pilot/calendar/service_calendar_month.dart';
import 'package:life_pilot/calendar/page_calendar_add.dart';
import 'package:life_pilot/event/event_copy_flow.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:life_pilot/utils/service/service_weather.dart';
import 'package:provider/provider.dart';

class _Auth extends ControllerAuth {
  @override
  String? get currentAccount => 'viewer@example.com';

  @override
  Future<void> refreshSubscriptionUsage({bool notify = true}) async {}
}

class _Notifications implements ControllerNotification {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Model extends ModelCalendar {
  final List<EventItem> saved = [];
  final List<DateTime> requests = [];
}

class _Loader extends ServiceCalendarMonth {
  final _Model model;
  _Loader(this.model);
  @override
  Future<List<EventItem>> loadMonth(
    ModelCalendarMonthQuery query, {
    bool Function()? shouldContinue,
    void Function(List<EventItem>)? onEventsReady,
  }) async {
    model.requests.add(query.month);
    return List.of(model.saved);
  }
}

// Simulate the saved editor result, including the invalidation performed by
// saveEventWithNotification. The test exercises the real copy navigation and
// ControllerCalendar.addEvent/reloadEvents without calling Supabase or plugins.
class _SavedEditor extends NavigatorObserver {
  _SavedEditor(this.model, {this.cancel = false});
  final _Model model;
  final bool cancel;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! MaterialPageRoute) return;
    final page = route.builder(navigator!.context);
    if (page is! PageCalendarAdd) return;
    scheduleMicrotask(() {
      final copy = page.templateEvent!;
      if (!cancel) {
        model.saved.add(copy);
        model.invalidateEventRange(
          startDate: copy.startDate,
          endDate: copy.endDate,
        );
      }
      navigator!.pop(cancel ? null : copy);
    });
  }
}

void main() {
  for (final crossMonth in [false, true]) {
    for (final cancel in [false, true]) {
      testWidgets(
        '${cancel ? 'cancel' : 'copy'} shared event preserves ${crossMonth ? 'cross-month' : 'current'} grid',
        (tester) async {
          final month = DateTime(2026, 10);
          final auth = _Auth();
          final locale = ProviderLocale(locale: const Locale('en'));
          final shared = EventItem(
            id: 'shared',
            name: 'Shared',
            account: 'owner@example.com',
            startDate: crossMonth
                ? DateTime(2026, 9, 30)
                : DateTime(2026, 10, 20),
            endDate: crossMonth ? DateTime(2026, 10, 2) : null,
          );
          final own = EventItem(
            id: 'own',
            name: 'Own',
            account: auth.currentAccount,
            startDate: DateTime(2026, 10, 20),
          );
          final model = _Model()..currentMonth = month;
          model.saved.addAll([own, shared]);
          model.cacheMonthEvents(month, List.of(model.saved));
          model.setMonthFromCache('2026-10');
          model.cacheMonthEvents(DateTime(2026, 9), [shared]);
          model.cacheMonthEvents(DateTime(2026, 11), [shared]);
          final calendar = ControllerCalendar(
            modelCalendar: model,
            monthLoader: _Loader(model),
            serviceEvent: ServiceEvent(),
            auth: auth,
            controllerNotification: _Notifications(),
            serviceWeather: ServiceWeather(),
            localeProvider: locale,
            tableName: TableNames.calendarEvents,
            toTableName: TableNames.memoryTrace,
            closeText: 'Close',
          );
          addTearDown(() {
            calendar.dispose();
            auth.dispose();
            locale.dispose();
          });
          final observer = _SavedEditor(model, cancel: cancel);
          EventItem? returned;
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<ControllerAuth>.value(value: auth),
                ChangeNotifierProvider<ControllerCalendar>.value(
                  value: calendar,
                ),
              ],
              child: MaterialApp(
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                navigatorObservers: [observer],
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      child: const Text('Copy'),
                      onPressed: () async {
                        returned = await copyEventToAnotherPage(
                          context: context,
                          event: shared,
                          sourceTableName: TableNames.calendarEvents,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Copy'));
          await tester.pumpAndSettle();
          final loc = AppLocalizations.of(
            tester.element(find.byType(ListTile).first),
          )!;
          await tester.tap(find.text(loc.personalEvent));
          await tester.pumpAndSettle();
          if (cancel) {
            expect(returned, isNull);
            expect(model.requests, isEmpty);
            expect(model.eventsForMonth(month).map((event) => event.id), [
              'own',
              'shared',
            ]);
            expect(model.eventsForMonth(DateTime(2026, 9)), isNotEmpty);
            expect(model.eventsForMonth(DateTime(2026, 11)), isNotEmpty);
          } else {
            expect(returned, isNotNull);
            expect(returned!.account, auth.currentAccount);
            expect(shared.account, 'owner@example.com');
            expect(model.requests, [month]);
            expect(calendar.currentMonth, month);
            expect(
              model.eventsForMonth(month).map((event) => event.id),
              containsAll(['own', 'shared', returned!.id]),
            );
            expect(
              calendar
                  .getEventsOfDay(
                    crossMonth ? DateTime(2026, 10, 1) : DateTime(2026, 10, 20),
                  )
                  .map((event) => event.id),
              containsAll(['shared', returned!.id]),
            );
            expect(model.eventsForMonth(DateTime(2026, 9)), isEmpty);
            expect(model.eventsForMonth(DateTime(2026, 11)), isEmpty);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/controller_notification.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/calendar/page_calendar.dart';
import 'package:life_pilot/calendar/widgets_calendar.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:life_pilot/utils/service/service_weather.dart';
import 'package:provider/provider.dart';

class _Auth extends ControllerAuth {
  @override
  String? get currentAccount => 'test@example.com';
  @override
  DataStorageLocation get preferredStorage => DataStorageLocation.cloud;
}

class _Notifications implements ControllerNotification {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Calendar extends ControllerCalendar {
  _Calendar(ModelCalendar model, ControllerAuth auth, ProviderLocale locale)
    : super(
        modelCalendar: model,
        serviceEvent: ServiceEvent(),
        auth: auth,
        controllerNotification: _Notifications(),
        serviceWeather: ServiceWeather(),
        localeProvider: locale,
        tableName: TableNames.calendarEvents,
        toTableName: TableNames.memoryTrace,
        closeText: 'Close',
      );
  @override
  Future<void> init() async {}
  @override
  Future<void> syncCompletedEventReminders() async {}
  @override
  Future<void> showTodayNotifications() async {}
  @override
  Future<void> goToMonth({required DateTime month, bool notify = true}) async {
    currentMonth = month;
  }

  void signal() => notifyListeners();
}

void main() {
  testWidgets(
    'unrelated notifications retain body; data and month still update',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final now = DateTime.now();
      final month = DateTime(now.year, now.month);
      final model = ModelCalendar()..currentMonth = month;
      EventItem event(String name) =>
          EventItem(id: name, name: name, startDate: month);
      model.cacheMonthEvents(month, [event('Original')]);
      final auth = _Auth();
      final locale = ProviderLocale(locale: const Locale('en'));
      final controller = _Calendar(model, auth, locale);
      addTearDown(() {
        controller.dispose();
        auth.dispose();
        locale.dispose();
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControllerAuth>.value(value: auth),
            ChangeNotifierProvider<ControllerCalendar>.value(value: controller),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PageCalendar(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final firstBody = tester.widget<CalendarBody>(find.byType(CalendarBody));
      expect(find.text('Original'), findsOneWidget);
      controller.signal();
      await tester.pump();
      expect(
        identical(
          firstBody,
          tester.widget<CalendarBody>(find.byType(CalendarBody)),
        ),
        true,
      );
      model.cacheMonthEvents(month, [event('Updated')]);
      controller.signal();
      await tester.pump();
      expect(find.text('Updated'), findsOneWidget);
      expect(find.text('Original'), findsNothing);
      controller.currentMonth = DateTime(month.year, month.month + 1);
      controller.signal();
      await tester.pump();
      expect(
        tester.widget<WeekDayHeader>(find.byType(WeekDayHeader)).isCurrentMonth,
        false,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

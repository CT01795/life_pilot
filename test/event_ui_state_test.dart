import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/service/service_weather.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final table in [
    TableNames.recommendEvents,
    TableNames.recommendPlaces,
    TableNames.memoryTrace,
  ]) {
    group(table, () {
      late ControllerAuth auth;
      late ModelEvent model;
      late ControllerEvent controller;
      late int notifications;
      final loc = AppLocalizationsEn();
      setUp(() {
        auth = ControllerAuth();
        model = ModelEvent()..setEvents([EventItem(id: 'a', name: 'A')]);
        controller = ControllerEvent(
          auth: auth,
          serviceEvent: ServiceEvent(),
          serviceWeather: ServiceWeather(),
          modelEvent: model,
          tableName: table,
        );
        notifications = 0;
        controller.addListener(() => notifications++);
      });
      tearDown(() {
        if (!controller.notifierDisposed) controller.dispose();
        auth.dispose();
      });

      test('selection publishes only actual membership changes', () {
        controller.toggleEventSelection('a', false);
        controller.toggleEventSelection('a', true);
        controller.toggleEventSelection('a', true);
        expect(notifications, 1);
        expect(controller.isEventSelected('a'), isTrue);
        controller.toggleEventSelection('a', false);
        controller.toggleEventSelection('a', false);
        expect(notifications, 2);
      });
      test('repeated search-panel state does not rebuild', () {
        controller.toggleSearchPanel(false, loc);
        controller.toggleSearchPanel(true, loc);
        controller.toggleSearchPanel(true, loc);
        expect(notifications, 1);
        expect(controller.showSearchPanel, isTrue);
      });
      test('equal dates retain revision and filtered snapshot', () {
        final day = DateTime(2026, 10, 29);
        controller.updateStartDate(day);
        controller.updateEndDate(day);
        final revision = controller.filterRevision;
        final snapshot = controller.getFilteredEvents(loc);
        notifications = 0;
        controller.updateStartDate(DateTime(2026, 10, 29));
        controller.updateEndDate(DateTime(2026, 10, 29));
        expect(controller.filterRevision, revision);
        expect(controller.getFilteredEvents(loc), same(snapshot));
        expect(notifications, 0);
        controller.updateStartDate(DateTime(2026, 11, 1));
        expect(model.searchFilter.endDate, DateTime(2026, 11, 1));
        controller.updateEndDate(day);
        expect(model.searchFilter.startDate, day);
        expect(notifications, 2);
        expect(controller.filterRevision, revision + 2);
      });
      test('disposed controller cannot mutate selection or date filters', () {
        controller.dispose();
        controller.toggleEventSelection('a', true);
        controller.toggleSearchPanel(true, loc);
        controller.updateStartDate(DateTime(2026, 10, 29));
        controller.updateEndDate(DateTime(2026, 10, 30));
        expect(model.selectedEventIds, isEmpty);
        expect(model.showSearchPanel, isFalse);
        expect(model.searchFilter.startDate, isNull);
        expect(model.searchFilter.endDate, isNull);
        expect(notifications, 0);
      });
    });
  }
}

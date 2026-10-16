import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';
import 'package:life_pilot/memory_trace/widgets_memory_card.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/model_event_weather.dart';

class _Controller extends ChangeNotifier implements ControllerEvent {
  final forecasts = <String, List<EventWeather>>{};
  bool get isObserved => hasListeners;

  @override
  List<EventWeather>? getForecast({required String locationDisplay}) =>
      forecasts[locationDisplay];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

EventWeather _weather(double temp) => EventWeather.fromJson({
  'date': DateTime.now().toIso8601String(),
  'main': 'Clear',
  'description': 'clear sky',
  'icon': '01d',
  'temp': temp,
});

Widget _screen(
  _Controller controller, {
  String name = 'Memory',
  Locale locale = const Locale('en'),
}) {
  final model = EventViewModel.buildEventViewModel(
    event: EventItem(
      id: 'memory',
      name: name,
      city: 'Taipei',
      location: 'Park',
      startDate: DateTime.now().add(const Duration(days: 1)),
    ),
    parentLocation: '',
    canDelete: false,
    loc: AppLocalizationsEn(),
    tableName: TableNames.memoryTrace,
  );
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: WidgetsMemoryCard(
          controllerEvent: controller,
          eventViewModel: model,
          tableName: TableNames.memoryTrace,
          onOpenMap: () {},
          onOpenLink: () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('background and other-location changes do not rebuild the card', (
    tester,
  ) async {
    final controller = _Controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_screen(controller));
    await tester.pumpAndSettle();
    final title = tester.widget<Text>(find.text('Memory'));
    for (var index = 0; index < 10; index++) {
      controller.notifyListeners();
      await tester.pump();
    }
    expect(identical(tester.widget<Text>(find.text('Memory')), title), true);
    controller.forecasts['Another city'] = [_weather(20)];
    controller.notifyListeners();
    await tester.pump();
    expect(identical(tester.widget<Text>(find.text('Memory')), title), true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('matching weather changes still refresh the card', (
    tester,
  ) async {
    final controller = _Controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_screen(controller));
    await tester.pumpAndSettle();
    final title = tester.widget<Text>(find.text('Memory'));
    // Read the same location formatting as the event view model.
    final card = tester.widget<WidgetsMemoryCard>(
      find.byType(WidgetsMemoryCard),
    );
    final key = card.eventViewModel.locationDisplay;
    controller.forecasts[key] = [_weather(20)];
    controller.notifyListeners();
    await tester.pumpAndSettle();
    expect(identical(tester.widget<Text>(find.text('Memory')), title), false);
    expect(find.byTooltip('Clear 20.0°C'), findsOneWidget);
    final updatedTitle = tester.widget<Text>(find.text('Memory'));
    controller.forecasts[key]![0] = _weather(25);
    controller.notifyListeners();
    await tester.pumpAndSettle();
    expect(
      identical(tester.widget<Text>(find.text('Memory')), updatedTitle),
      false,
    );
    expect(find.byTooltip('Clear 25.0°C'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('controller replacement, edited content and locale remain live', (
    tester,
  ) async {
    final first = _Controller(), second = _Controller();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(_screen(first));
    await tester.pumpAndSettle();
    expect(first.isObserved, true);
    await tester.pumpWidget(
      _screen(second, name: 'Edited', locale: const Locale('ja')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edited'), findsOneWidget);
    expect(find.text('Memory'), findsNothing);
    expect(first.isObserved, false);
    expect(second.isObserved, true);
    first.notifyListeners();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(second.isObserved, false);
    second.notifyListeners();
    expect(tester.takeException(), isNull);
  });
}

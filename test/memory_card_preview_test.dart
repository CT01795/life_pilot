import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';
import 'package:life_pilot/memory_trace/widgets_memory_card.dart';
import 'package:life_pilot/memory_trace/widgets_memory_sub_card.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/model_event_weather.dart';

class _Controller extends ChangeNotifier implements ControllerEvent {
  @override
  List<EventWeather>? getForecast({required String locationDisplay}) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CountingLocale extends AppLocalizationsEn {
  int reads = 0;
  @override
  String get free {
    reads++;
    return super.free;
  }
}

EventItem _memory(int count) => EventItem(
  id: 'parent',
  name: 'Parent',
  startDate: DateTime(2026, 10, 1),
  subEvents: List.generate(
    count,
    (i) => EventItem(
      id: 'child-$i',
      name: 'Child $i',
      isFree: true,
      startDate: DateTime(2026, 10, 1),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('view model only formats child records when accessed', () {
    final loc = _CountingLocale();
    final model = EventViewModel.buildEventViewModel(
      event: _memory(1000),
      parentLocation: '',
      canDelete: false,
      loc: loc,
      tableName: TableNames.memoryTrace,
    );
    expect(loc.reads, 0);
    expect(model.subEvents.length, 1000);
    expect(model.subEvents.isNotEmpty, true);
    expect(loc.reads, 0);
    expect(model.subEvents.take(3).map((item) => item.name), [
      'Child 0',
      'Child 1',
      'Child 2',
    ]);
    expect(loc.reads, 3);
    expect(identical(model.subEvents[0], model.subEvents[0]), true);
    expect(loc.reads, 3);
  });

  testWidgets('list skips child widgets; full preview retains all', (
    tester,
  ) async {
    final controller = _Controller();
    addTearDown(controller.dispose);
    final model = EventViewModel.buildEventViewModel(
      event: _memory(8),
      parentLocation: '',
      canDelete: false,
      loc: AppLocalizationsEn(),
      tableName: TableNames.memoryTrace,
    );
    var taps = 0;
    Widget screen({required bool showSubEvents}) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: WidgetsMemoryCard(
            controllerEvent: controller,
            eventViewModel: model,
            tableName: TableNames.memoryTrace,
            showSubEvents: showSubEvents,
            onOpenMap: () {},
            onOpenLink: () {},
            onTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.pumpWidget(screen(showSubEvents: false));
    await tester.pumpAndSettle();
    expect(find.byType(WidgetsMemorySubCard), findsNothing);
    await tester.tap(find.text('Parent'));
    expect(taps, 1);
    await tester.pumpWidget(screen(showSubEvents: true));
    await tester.pumpAndSettle();
    expect(find.byType(WidgetsMemorySubCard), findsNWidgets(8));
    expect(find.byType(TextButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

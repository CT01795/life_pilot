import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/model_calendar_week_layout.dart';
import 'package:life_pilot/calendar/widgets_calendar.dart';
import 'package:life_pilot/event/model_event_item.dart';

class _Event extends EventItem {
  _Event()
    : super(
        id: 'a',
        name: 'Event',
        startDate: DateTime(2026, 10, 6),
        endDate: DateTime(2026, 10, 8),
      );
  int reads = 0;
  @override
  DateTime? get startDate {
    reads++;
    return super.startDate;
  }
}

class _Calendar extends ChangeNotifier implements ControllerCalendar {
  _Calendar(EventItem event)
    : rows = ModelCalendarWeekLayout([
        event,
      ]).forWeek(DateTime(2026, 10, 4), DateTime(2026, 10, 10));
  final List<EventWithRow> rows;
  @override
  List<EventWithRow> getEventRowsForWeek({
    required DateTime month,
    required int weekIndex,
  }) => rows;
  @override
  Color eventOwnerColor(EventItem event) => Colors.blue;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends ChangeNotifier implements ControllerAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'resizing and rebuilds reuse placement while scaling its pixels',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final event = _Event();
      final controller = _Calendar(event);
      final auth = _Auth();
      addTearDown(controller.dispose);
      addTearDown(auth.dispose);
      final week = List.generate(7, (i) => DateTime(2026, 10, 4 + i));
      Widget app(double width) =>
          ChangeNotifierProvider<ControllerCalendar>.value(
            value: controller,
            child: MaterialApp(
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    height: 160,
                    child: WeekRow(
                      controllerCalendar: controller,
                      auth: auth,
                      week: week,
                      displayedMonth: DateTime(2026, 10),
                      weekIndex: 1,
                    ),
                  ),
                ),
              ),
            ),
          );
      for (final width in [350.0, 700.0, 350.0]) {
        await tester.pumpWidget(app(width));
        await tester.pumpAndSettle();
        final row = tester.widget<PositionedDirectional>(
          find.descendant(
            of: find.byType(WeekRow),
            matching: find.byType(PositionedDirectional),
          ),
        );
        expect(row.start, closeTo(2 * width / 7, .001));
        expect(row.end, closeTo(2 * width / 7, .001));
        expect(event.reads, 1);
        controller.notifyListeners();
        await tester.pump();
        expect(event.reads, 1);
        expect(tester.takeException(), null);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}

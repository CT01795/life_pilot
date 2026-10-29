import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/controller_calendar_ui.dart' as calendar_ui;
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/controller_event_ui.dart' as event_ui;
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/utils/const.dart';

class _PendingActions {
  int deletes = 0;
  final deleted = Completer<void>();
  final duplicate = Completer<bool>();
  Future<void> deleteEvent(EventItem event) {
    deletes++;
    return deleted.future;
  }

  Future<bool> handleEventCheckboxIsAlreadyAdd(EventItem event, bool checked) =>
      duplicate.future;
  bool canDelete({required String account, bool isApproved = false}) => true;
  String get fromTableName => TableNames.recommendEvents;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Calendar extends _PendingActions implements ControllerCalendar {}

class _Events extends _PendingActions implements ControllerEvent {}

void main() {
  final loc = AppLocalizationsEn();
  final event = EventItem(id: 'a', name: 'Event');
  for (final calendar in [true, false]) {
    group(calendar ? 'calendar UI' : 'event/memory UI', () {
      late _PendingActions actions;
      late Future<void> Function(BuildContext) delete;
      late Future<void> Function(BuildContext) transfer;
      late BuildContext source;
      late StateSetter rebuild;
      late bool visible;
      Future<void> mount(WidgetTester tester) async {
        visible = true;
        if (calendar) {
          final controller = _Calendar();
          actions = controller;
          delete = (context) => calendar_ui.onDeletePressed(
            context: context,
            controller: controller,
            event: event,
            loc: loc,
          );
          transfer = (context) => calendar_ui.onMemoryCheckboxChanged(
            context: context,
            controller: controller,
            value: true,
            event: event,
            loc: loc,
            selectedDate: DateTime(2026, 10, 29),
          );
        } else {
          final controller = _Events();
          actions = controller;
          delete = (context) => event_ui.onDeletePressed(
            context: context,
            controller: controller,
            event: event,
            loc: loc,
          );
          transfer = (context) => event_ui.onMemoryCheckboxChanged(
            context: context,
            controller: controller,
            value: true,
            event: event,
            loc: loc,
          );
        }
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigatorKey,
            scaffoldMessengerKey: scaffoldMessengerKey,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return visible
                      ? Builder(
                          builder: (context) {
                            source = context;
                            return const Text('Source');
                          },
                        )
                      : const Text('Replacement');
                },
              ),
            ),
          ),
        );
      }

      Future<void> removeSource(WidgetTester tester) async {
        rebuild(() => visible = false);
        await tester.pump();
        expect(source.mounted, isFalse);
      }

      testWidgets('confirmation after source removal cannot start deletion', (
        tester,
      ) async {
        await mount(tester);
        final operation = delete(source);
        await tester.pumpAndSettle();
        await removeSource(tester);
        await tester.tap(find.text(loc.delete));
        await tester.pumpAndSettle();
        await operation;
        expect(actions.deletes, 0);
        expect(tester.takeException(), isNull);
      });
      for (final fails in [false, true]) {
        testWidgets(
          'late deletion result ignores removed source (failure: $fails)',
          (tester) async {
            await mount(tester);
            final operation = delete(source);
            await tester.pumpAndSettle();
            await tester.tap(find.text(loc.delete));
            await tester.pumpAndSettle();
            expect(actions.deletes, 1);
            await removeSource(tester);
            if (fails) {
              actions.deleted.completeError(StateError('offline'));
            } else {
              actions.deleted.complete();
            }
            await operation;
            await tester.pumpAndSettle();
            expect(find.text('Replacement'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
      testWidgets('late duplicate check cannot open a transfer dialog', (
        tester,
      ) async {
        await mount(tester);
        final operation = transfer(source);
        await removeSource(tester);
        actions.duplicate.complete(false);
        await operation;
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });
  }
}

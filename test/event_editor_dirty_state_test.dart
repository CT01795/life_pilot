import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/controller_page_calendar_add.dart';
import 'package:life_pilot/calendar/page_calendar_add.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/controller_page_event_add.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/memory_trace/page_memory_add.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:provider/provider.dart';

class _Auth extends ControllerAuth {
  @override
  String? get currentAccount => 'member@example.com';

  @override
  bool get isPlus => false;

  @override
  bool get storesNewDataLocally => false;
}

class _Calendar implements ControllerCalendar {
  _Calendar(this.auth);
  @override
  final ControllerAuth auth;

  @override
  ControllerPageCalendarAdd createAddController({
    EventItem? existingEvent,
    EventItem? templateEvent,
    DateTime? initialDate,
  }) => ControllerPageCalendarAdd(
    auth: auth,
    tableName: TableNames.calendarEvents,
    existingEvent: existingEvent,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Memory implements ControllerEvent {
  _Memory(this.auth);
  @override
  final ControllerAuth auth;

  @override
  ControllerPageEventAdd createAddController({
    EventItem? existingEvent,
    EventItem? templateEvent,
    DateTime? initialDate,
  }) => ControllerPageEventAdd(
    auth: auth,
    tableName: TableNames.memoryTrace,
    existingEvent: existingEvent,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final calendar in [true, false]) {
    final editor = calendar ? 'calendar' : 'memory';
    for (final edit in [false, true]) {
      testWidgets('$editor: editing=$edit controls the discard prompt', (
        tester,
      ) async {
        final auth = _Auth();
        addTearDown(auth.dispose);
        final existing = EventItem(id: 'existing', name: 'Original');
        await tester.pumpWidget(
          ChangeNotifierProvider<ControllerAuth>.value(
            value: auth,
            child: MaterialApp(
              navigatorKey: navigatorKey,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => calendar
                          ? PageCalendarAdd(
                              controllerCalendar: _Calendar(auth),
                              existingEvent: existing,
                            )
                          : PageMemoryAdd(
                              controllerEvent: _Memory(auth),
                              existingEvent: existing,
                            ),
                    ),
                  ),
                  child: const Text('Open form'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open form'));
        await tester.pumpAndSettle();
        final field = find.byType(EditableText).first;
        await tester.tap(field);
        await tester.pump();
        tester.widget<EditableText>(field).controller.selection =
            const TextSelection(baseOffset: 1, extentOffset: 3);
        if (edit) await tester.enterText(field, 'Edited');
        await tester.pump();
        final loc = AppLocalizations.of(tester.element(field))!;

        await navigatorKey.currentState!.maybePop();
        await tester.pumpAndSettle();
        expect(
          find.text(loc.unsavedChangesPrompt),
          edit ? findsOne : findsNothing,
        );
        if (!edit) expect(find.text('Open form'), findsOne);
      });
    }
  }
}

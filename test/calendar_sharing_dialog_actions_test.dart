import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/service_calendar_sharing.dart';
import 'package:life_pilot/calendar/widgets_calendar_sharing_dialog.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _Auth extends ControllerAuth {
  @override
  bool get isSysAdmin => true;

  @override
  Future<void> refreshSubscriptionUsage({bool notify = true}) async {}
}

class _Sharing extends ServiceCalendarSharing {
  final submitted = Completer<void>();
  int calls = 0;
  List<String> emails = [];
  Set<String> ids = {};

  @override
  Future<CalendarSharingState> load({
    required Iterable<EventItem> visibleEvents,
  }) async => CalendarSharingState(
    sent: const [],
    received: const [],
    sharedEvents: const [],
    shareableEvents: List.generate(
      25,
      (index) => CalendarShareableEvent(
        id: 'event-$index',
        name: 'Event $index',
        startDate: DateTime(2026, 10, 20),
      ),
    ),
  );

  @override
  Future<void> inviteAll(
    Iterable<String> emails,
    Iterable<String> eventIds,
  ) async {
    calls++;
    this.emails = emails.toList();
    ids = eventIds.toSet();
    await submitted.future;
  }
}

void main() {
  for (final language in ['zh', 'en', 'ja', 'ko']) {
    for (final size in [const Size(320, 740), const Size(1024, 768)]) {
      testWidgets(
        '$language $size fixed send remains available below a long list',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final auth = _Auth();
          final service = _Sharing();
          addTearDown(() {
            if (!service.submitted.isCompleted) service.submitted.complete();
            auth.dispose();
          });
          await tester.pumpWidget(
            ChangeNotifierProvider<ControllerAuth>.value(
              value: auth,
              child: MaterialApp(
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => CalendarSharingDialog(
                          service: service,
                          visibleEvents: const [],
                          onSharingChanged: () async {},
                        ),
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final footer = find.byKey(const ValueKey('calendar-share-send'));
          expect(tester.widget<FilledButton>(footer).onPressed, isNull);
          final loc = AppLocalizations.of(
            tester.element(find.byType(CalendarSharingDialog)),
          )!;
          await tester.enterText(find.byType(TextField).first, 'not-an-email');
          final scroll = tester
              .widget<Scrollbar>(find.byType(Scrollbar))
              .controller!;
          scroll.jumpTo(scroll.position.maxScrollExtent);
          await tester.pumpAndSettle();
          // A shrink-wrapped dialog can grow after the translated title wraps.
          scroll.jumpTo(scroll.position.maxScrollExtent);
          await tester.pumpAndSettle();
          await tester.tap(find.text(loc.calendarShareEvents));
          await tester.pumpAndSettle();
          final initialPosition = tester.getRect(footer);
          scroll.jumpTo(scroll.position.maxScrollExtent);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Event 24'));
          await tester.pumpAndSettle();
          expect(tester.getRect(footer), initialPosition);
          expect(
            tester.getRect(find.byType(ListView)).bottom,
            lessThanOrEqualTo(tester.getRect(footer).top),
          );
          expect(tester.takeException(), isNull);
          await tester.tap(footer);
          await tester.pumpAndSettle();
          expect(service.calls, 0);
          expect(scroll.offset, 0);
          expect(find.text(loc.invalidEmail), findsOneWidget);
          await tester.enterText(
            find.byType(TextField).first,
            'friend@example.com',
          );
          scroll.jumpTo(scroll.position.maxScrollExtent);
          await tester.pumpAndSettle();
          await tester.tap(footer);
          await tester.pump();
          expect(service.calls, 1);
          expect(service.emails, ['friend@example.com']);
          expect(service.ids, {'event-24'});
          expect(tester.widget<FilledButton>(footer).onPressed, isNull);
          service.submitted.complete();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

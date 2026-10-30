import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/service_event_tracking.dart';
import 'package:life_pilot/utils/service/service_external_link.dart';

void main() {
  test(
    'account change during navigation never attributes an old intent to the new account',
    () async {
      var account = 'a', writes = 0;
      final gate = Completer<bool>();
      final service = EventTrackingService(
        accountScope: () => account,
        links: ServiceExternalLink(launcher: (_) => gate.future),
        counterWriter:
            ({required eventId, required eventName, required column}) async {
              writes++;
            },
      );
      final opening = service.openEventLink(
        eventId: 'e',
        eventName: 'n',
        url: 'https://example.com',
      );
      account = 'b';
      gate.complete(true);
      expect(await opening, true);
      expect(writes, 0);
    },
  );
  test(
    'pending duplicate navigation opens and counts once; later intent counts again',
    () async {
      var opens = 0, writes = 0;
      var account = 'a';
      Completer<void>? gate = Completer<void>();
      final service = EventTrackingService(
        accountScope: () => account,
        links: ServiceExternalLink(
          launcher: (_) async {
            opens++;
            return true;
          },
        ),
        counterWriter:
            ({required eventId, required eventName, required column}) async {
              writes++;
              final waiting = gate;
              if (waiting != null) await waiting.future;
            },
      );
      Future<bool> open([String destination = 'https://example.com']) => service
          .openEventLink(eventId: 'event', eventName: 'name', url: destination);
      final first = open(), duplicate = open();
      expect(identical(first, duplicate), true);
      await Future<void>.delayed(Duration.zero);
      expect(opens, 1);
      expect(writes, 1);
      account = 'b';
      final otherAccount = open();
      final otherDestination = open('https://other.example.com');
      await Future<void>.delayed(Duration.zero);
      expect(opens, 3);
      gate.complete();
      await Future.wait([first, duplicate, otherAccount, otherDestination]);
      gate = null;
      await open();
      expect(opens, 4);
      expect(writes, 4);
    },
  );
  test(
    'failed open releases pending state and never adds statistics',
    () async {
      var succeeds = false, writes = 0;
      final service = EventTrackingService(
        accountScope: () => 'a',
        links: ServiceExternalLink(launcher: (_) async => succeeds),
        counterWriter:
            ({required eventId, required eventName, required column}) async {
              writes++;
            },
      );
      Future<bool> open() => service.openEventLink(
        eventId: 'e',
        eventName: 'n',
        url: 'https://example.com',
      );
      expect(await open(), false);
      expect(writes, 0);
      succeeds = true;
      expect(await open(), true);
      expect(writes, 1);
    },
  );
}

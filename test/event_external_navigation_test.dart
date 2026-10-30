import 'dart:async';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/controller_notification.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/model_external_destination.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/event/service_event_tracking.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:life_pilot/utils/service/service_external_link.dart';
import 'package:life_pilot/utils/service/service_notification/service_notification_platform.dart';
import 'package:life_pilot/utils/service/service_weather.dart';

class _Auth extends ControllerAuth {
  @override
  String get currentAccount => 'user@example.com';
}

class _Notifications implements ServiceNotificationPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

EventViewModel _event(String table) => EventViewModel.buildEventViewModel(
  event: EventItem(
    id: 'event',
    name: 'An event',
    city: '  桃園  ',
    location: '中正路 1 號',
    masterUrl: 'https://example.com/event',
  ),
  parentLocation: '',
  canDelete: false,
  loc: lookupAppLocalizations(const Locale('zh')),
  tableName: table,
);

class _Tracking extends EventTrackingService {
  final links = <String?>[];
  final destinations = <(String?, String?)>[];
  @override
  Future<bool> openEventLink({
    required String eventId,
    required String eventName,
    required String? url,
  }) async {
    links.add(url);
    return true;
  }

  @override
  Future<bool> openEventMap({
    required String eventId,
    required String eventName,
    required String? city,
    required String? location,
  }) async {
    destinations.add((city, location));
    return true;
  }
}

void main() {
  setUp(() {
    supabase = SupabaseClient('https://example.supabase.co', 'test-key');
  });
  tearDown(() => supabase.dispose());
  test('map destination omits missing and whitespace-only address parts', () {
    expect(ModelExternalDestination.map(city: null, location: null), isNull);
    expect(ModelExternalDestination.map(city: ' ', location: '\n'), isNull);
    expect(
      ModelExternalDestination.map(
        city: '  桃園 ',
      )!.queryParameters['destination'],
      '桃園',
    );
    expect(
      ModelExternalDestination.map(
        location: '  台北車站  ',
      )!.queryParameters['destination'],
      '台北車站',
    );
  });

  test('map URI encodes Chinese and reserved characters exactly once', () {
    final uri = ModelExternalDestination.map(
      city: '桃園',
      location: 'A&B #1 / 入口',
    )!;
    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['destination'], '桃園．A&B #1 / 入口');
  });

  test(
    'URL parser trims external URLs and rejects empty, relative or malformed input',
    () {
      expect(
        ModelExternalDestination.link(
          ' https://example.com/event?a=1#top ',
        )!.toString(),
        'https://example.com/event?a=1#top',
      );
      for (final value in [
        null,
        '',
        ' ',
        '/relative',
        'https://',
        'https://[',
      ]) {
        expect(ModelExternalDestination.link(value), isNull);
      }
      expect(
        ModelExternalDestination.link('mailto:info@example.com')!.scheme,
        'mailto',
      );
    },
  );

  test('invalid destinations do not invoke the platform launcher', () async {
    var launches = 0;
    final links = ServiceExternalLink(
      launcher: (_) async {
        launches++;
        return true;
      },
    );
    expect(await links.openUrl(' '), isFalse);
    expect(await links.openMap(city: null, location: ''), isFalse);
    expect(launches, 0);
  });

  test('launcher refusal and platform exception both return false', () async {
    final refused = ServiceExternalLink(launcher: (_) async => false);
    final failed = ServiceExternalLink(
      launcher: (_) async => throw StateError('platform unavailable'),
    );
    expect(await refused.openUrl('https://example.com'), isFalse);
    expect(await failed.openUrl('https://example.com'), isFalse);
  });

  test(
    'launch happens before counter writing even when the database is slow',
    () async {
      final sequence = <String>[];
      final counter = Completer<void>();
      final service = EventTrackingService(
        links: ServiceExternalLink(
          launcher: (_) async {
            sequence.add('launch');
            return true;
          },
        ),
        counterWriter:
            ({required eventId, required eventName, required column}) async {
              sequence.add(column);
              await counter.future;
            },
      );
      final opening = service.openEventLink(
        eventId: 'event',
        eventName: 'name',
        url: 'https://example.com',
      );
      await Future<void>.delayed(Duration.zero);
      expect(sequence, ['launch', 'page_views']);
      counter.complete();
      expect(await opening, isTrue);
    },
  );

  test('failed link launch does not count page views', () async {
    var writes = 0;
    final service = EventTrackingService(
      links: ServiceExternalLink(launcher: (_) async => false),
      counterWriter:
          ({required eventId, required eventName, required column}) async {
            writes++;
          },
    );
    expect(
      await service.openEventLink(
        eventId: 'event',
        eventName: 'name',
        url: 'https://example.com',
      ),
      isFalse,
    );
    expect(writes, 0);
  });

  test(
    'successful navigation counts one card click and preserves identity',
    () async {
      final calls = <(String, String, String)>[];
      Uri? launched;
      final service = EventTrackingService(
        links: ServiceExternalLink(
          launcher: (uri) async {
            launched = uri;
            return true;
          },
        ),
        counterWriter:
            ({required eventId, required eventName, required column}) async {
              calls.add((eventId, eventName, column));
            },
      );
      expect(
        await service.openEventMap(
          eventId: 'event',
          eventName: 'name',
          city: null,
          location: '台北車站',
        ),
        isTrue,
      );
      expect(launched!.queryParameters['destination'], '台北車站');
      expect(calls, [('event', 'name', 'card_clicks')]);
    },
  );

  test(
    'counter failure cannot turn a successful launch into a launch error',
    () async {
      final service = EventTrackingService(
        links: ServiceExternalLink(launcher: (_) async => true),
        counterWriter:
            ({required eventId, required eventName, required column}) async {
              throw StateError('database unavailable');
            },
      );
      expect(
        await service.openEventLink(
          eventId: 'event',
          eventName: 'name',
          url: 'https://example.com',
        ),
        isTrue,
      );
    },
  );

  test('plain links and maps do not implicitly add counters', () async {
    var writes = 0;
    final service = EventTrackingService(
      links: ServiceExternalLink(launcher: (_) async => true),
      counterWriter:
          ({required eventId, required eventName, required column}) async {
            writes++;
          },
    );
    expect(await service.launchUrlLink('https://example.com'), isTrue);
    expect(await service.onOpenMap('桃園', null), isTrue);
    expect(writes, 0);
    await service.incrementEventCounter(
      eventId: 'event',
      eventName: 'name',
      column: 'saves',
    );
    expect(writes, 1);
  });

  for (final table in [
    TableNames.recommendEvents,
    TableNames.recommendPlaces,
    TableNames.memoryTrace,
  ]) {
    test(
      '$table Controller delegates navigation and ignores actions after disposal',
      () async {
        final auth = _Auth();
        final tracking = _Tracking();
        final controller = ControllerEvent(
          auth: auth,
          serviceEvent: ServiceEvent(),
          serviceWeather: ServiceWeather(),
          modelEvent: ModelEvent(),
          tableName: table,
          eventTracking: tracking,
        );
        final event = _event(table);
        await controller.onOpenLink(event);
        await controller.onOpenMap(event);
        expect(tracking.links, ['https://example.com/event']);
        expect(tracking.destinations, [('  桃園  ', '中正路 1 號')]);
        controller.dispose();
        await controller.onOpenLink(event);
        await controller.onOpenMap(event);
        expect(tracking.links.length, 1);
        expect(tracking.destinations.length, 1);
        auth.dispose();
      },
    );
  }

  test(
    'calendar Controller uses the same navigation service and disposal guard',
    () async {
      final auth = _Auth();
      final tracking = _Tracking();
      final locale = ProviderLocale(locale: const Locale('zh'));
      final controller = ControllerCalendar(
        modelCalendar: ModelCalendar(),
        serviceEvent: ServiceEvent(),
        auth: auth,
        controllerNotification: ControllerNotification(
          service: _Notifications(),
        ),
        serviceWeather: ServiceWeather(),
        localeProvider: locale,
        tableName: TableNames.calendarEvents,
        toTableName: TableNames.memoryTrace,
        closeText: 'Close',
        eventTracking: tracking,
      );
      final event = _event(TableNames.calendarEvents);
      await controller.onOpenLink(event);
      await controller.onOpenMap(event);
      expect(tracking.links, ['https://example.com/event']);
      expect(tracking.destinations.length, 1);
      controller.dispose();
      await controller.onOpenLink(event);
      await controller.onOpenMap(event);
      expect(tracking.links.length, 1);
      expect(tracking.destinations.length, 1);
      locale.dispose();
      auth.dispose();
    },
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_city.dart';
import 'package:life_pilot/pages/home/controller_dashboard.dart';
import 'package:life_pilot/pages/home/repository/repository_dashboard.dart';
import 'package:life_pilot/utils/provider_locale.dart';

class _Repository extends DashboardRepository {
  final events = <Completer<List<DashboardCity>>>[];
  final places = <Completer<List<DashboardCity>>>[];

  Future<List<DashboardCity>> _read(
    List<Completer<List<DashboardCity>>> queue,
  ) {
    final request = Completer<List<DashboardCity>>();
    queue.add(request);
    return request.future;
  }

  @override
  Future<List<DashboardCity>> loadEventCities() => _read(events);

  @override
  Future<List<DashboardCity>> loadPlaceCities() => _read(places);
}

void main() {
  for (final event in [true, false]) {
    group(event ? 'event cities' : 'place cities', () {
      late _Repository repository;
      late ControllerDashboard model;
      List<Completer<List<DashboardCity>>> requests() =>
          event ? repository.events : repository.places;
      List<DashboardCity> cities() =>
          event ? model.eventCities : model.placeCities;
      Future<void> load({String account = 'user', bool force = false}) => event
          ? model.loadEventCities(account, forceRefresh: force)
          : model.loadPlaceCities(account, forceRefresh: force);
      Future<void> flush() => Future<void>.delayed(Duration.zero);
      List<DashboardCity> data(String name) => [
        DashboardCity(name: name, count: 1),
      ];

      setUp(() {
        repository = _Repository();
        model = ControllerDashboard(
          repository: repository,
          localeProvider: ProviderLocale(locale: const Locale('zh')),
        )..switchAccount('user');
      });
      tearDown(() {
        if (!model.notifierDisposed) model.dispose();
      });

      test('parallel forced refreshes share a single follow-up', () async {
        final initial = load();
        final forces = List.generate(8, (_) => load(force: true));
        expect(requests().length, 1);
        requests().first.complete(data('old'));
        await initial;
        await flush();
        expect(requests().length, 2);
        requests().last.complete(data('updated'));
        await Future.wait(forces);
        expect(cities().single.name, 'updated');
      });

      test(
        'ordinary calls share reads and successful empty results are cached',
        () async {
          final first = load();
          final second = load();
          expect(requests().length, 1);
          requests().single.complete([]);
          await Future.wait([first, second]);
          await load();
          expect(requests().length, 1);
        },
      );

      test(
        'account switching drops queued requests and stale results',
        () async {
          final old = load();
          final queued = load(force: true);
          model.switchAccount('other');
          final current = load(account: 'other');
          requests()[1].complete(data('current'));
          await current;
          requests()[0].complete(data('stale'));
          await Future.wait([old, queued]);
          expect(requests().length, 2);
          expect(cities().single.name, 'current');
        },
      );

      test(
        'signing back into the same email does not revive an old queue',
        () async {
          final old = load();
          final queued = load(force: true);
          model.switchAccount(null);
          model.switchAccount('user');
          final current = load();
          requests()[1].complete(data('current'));
          await current;
          requests()[0].complete(data('stale'));
          await Future.wait([old, queued]);
          expect(requests().length, 2);
          expect(cities().single.name, 'current');
        },
      );

      test('disposal prevents queued reads and late publications', () async {
        final first = load();
        final queued = load(force: true);
        model.dispose();
        requests().single.complete(data('stale'));
        await Future.wait([first, queued]);
        expect(requests().length, 1);
        expect(cities(), isEmpty);
      });

      test('a failed initial read still permits the queued refresh', () async {
        final first = load();
        final queued = load(force: true);
        requests().first.completeError(StateError('source unavailable'));
        await first;
        await flush();
        expect(requests().length, 2);
        requests().last.complete(data('recovered'));
        await queued;
        expect(cities().single.name, 'recovered');
      });

      test('wrong-account callers cannot queue a forced refresh', () async {
        final first = load();
        await load(account: 'wrong', force: true);
        requests().single.complete(data('current'));
        await first;
        expect(requests().length, 1);
      });
    });
  }
}

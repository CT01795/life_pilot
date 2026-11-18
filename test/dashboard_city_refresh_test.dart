import 'dart:async';

import 'support/dashboard_recommendation_test_mixin.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/controller_dashboard.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_city.dart';
import 'package:life_pilot/pages/home/repository/repository_dashboard.dart';
import 'package:life_pilot/utils/provider_locale.dart';

typedef _CityResult = ({
  List<DashboardCity> events,
  List<DashboardCity> places,
});

class _Repository extends DashboardRepository
    with DashboardRecommendationTestMixin {
  final requests = <Completer<_CityResult>>[];

  @override
  Future<_CityResult> loadRecommendationCityCounts() {
    final request = Completer<_CityResult>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  late _Repository repository;
  late ControllerDashboard model;
  late ProviderLocale locale;

  Future<void> load({String account = 'user', bool force = false}) =>
      model.loadRecommendationCities(account, forceRefresh: force);
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  _CityResult data(String name) => (
    events: [DashboardCity(name: '$name-event', count: 1)],
    places: [DashboardCity(name: '$name-place', count: 2)],
  );

  setUp(() {
    repository = _Repository();
    locale = ProviderLocale(locale: const Locale('zh'));
    model = ControllerDashboard(repository: repository, localeProvider: locale)
      ..switchAccount('user');
  });
  tearDown(() {
    if (!model.notifierDisposed) model.dispose();
    locale.dispose();
  });

  test('one read populates and caches both city lists', () async {
    final first = load();
    final second = load();
    expect(repository.requests, hasLength(1));
    repository.requests.single.complete(data('initial'));
    await Future.wait([first, second]);

    await load();
    expect(repository.requests, hasLength(1));
    expect(model.eventCities.single.name, 'initial-event');
    expect(model.placeCities.single.name, 'initial-place');
  });

  test('parallel forced refreshes share a single follow-up', () async {
    final initial = load();
    final forces = List.generate(8, (_) => load(force: true));
    expect(repository.requests, hasLength(1));
    repository.requests.first.complete(data('old'));
    await initial;
    await flush();
    expect(repository.requests, hasLength(2));
    repository.requests.last.complete(data('updated'));
    await Future.wait(forces);
    expect(model.eventCities.single.name, 'updated-event');
    expect(model.placeCities.single.name, 'updated-place');
  });

  test('account switching drops queued requests and stale results', () async {
    final old = load();
    final queued = load(force: true);
    model.switchAccount('other');
    final current = load(account: 'other');
    repository.requests[1].complete(data('current'));
    await current;
    repository.requests[0].complete(data('stale'));
    await Future.wait([old, queued]);
    expect(repository.requests, hasLength(2));
    expect(model.eventCities.single.name, 'current-event');
    expect(model.placeCities.single.name, 'current-place');
  });

  test(
    'signing back into the same email does not revive an old queue',
    () async {
      final old = load();
      final queued = load(force: true);
      model.switchAccount(null);
      model.switchAccount('user');
      final current = load();
      repository.requests[1].complete(data('current'));
      await current;
      repository.requests[0].complete(data('stale'));
      await Future.wait([old, queued]);
      expect(repository.requests, hasLength(2));
      expect(model.eventCities.single.name, 'current-event');
      expect(model.placeCities.single.name, 'current-place');
    },
  );

  test('disposal prevents queued reads and late publications', () async {
    final first = load();
    final queued = load(force: true);
    model.dispose();
    repository.requests.single.complete(data('stale'));
    await Future.wait([first, queued]);
    expect(repository.requests, hasLength(1));
    expect(model.eventCities, isEmpty);
    expect(model.placeCities, isEmpty);
  });

  test('a failed initial read still permits the queued refresh', () async {
    final first = load();
    final queued = load(force: true);
    repository.requests.first.completeError(StateError('source unavailable'));
    await first;
    await flush();
    expect(repository.requests, hasLength(2));
    repository.requests.last.complete(data('recovered'));
    await queued;
    expect(model.eventCities.single.name, 'recovered-event');
    expect(model.placeCities.single.name, 'recovered-place');
  });

  test('wrong-account callers cannot queue a forced refresh', () async {
    final first = load();
    await load(account: 'wrong', force: true);
    repository.requests.single.complete(data('current'));
    await first;
    expect(repository.requests, hasLength(1));
  });
}

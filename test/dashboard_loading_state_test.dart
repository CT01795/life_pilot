import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/controller_dashboard.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';
import 'package:life_pilot/pages/home/repository/repository_dashboard.dart';
import 'package:life_pilot/utils/provider_locale.dart';

class _Repository extends DashboardRepository {
  final events = <Completer<List<RecommendedEvent>>>[];
  final places = <Completer<List<RecommendedPlace>>>[];
  @override
  Future<List<RecommendedEvent>> loadRecommendEvents(String city) {
    final pending = Completer<List<RecommendedEvent>>();
    events.add(pending);
    return pending.future;
  }

  @override
  Future<List<RecommendedPlace>> loadRecommendPlaces(String city) {
    final pending = Completer<List<RecommendedPlace>>();
    places.add(pending);
    return pending.future;
  }
}

void main() {
  late _Repository repository;
  late ControllerDashboard model;
  late ProviderLocale locale;
  setUp(() {
    repository = _Repository();
    locale = ProviderLocale(locale: const Locale('en'));
    model = ControllerDashboard(repository: repository, localeProvider: locale)
      ..switchAccount('user');
  });
  tearDown(() {
    if (!model.notifierDisposed) model.dispose();
    locale.dispose();
  });

  test('one finished section does not hide another active section', () async {
    final events = model.refreshRecommendEvent(account: 'user');
    final places = model.refreshRecommendPlace(account: 'user');
    repository.events.single.complete([]);
    await events;
    expect(model.loading, true);
    expect(model.isLoading(DashboardSection.recommendEvents), false);
    expect(model.isLoading(DashboardSection.recommendPlaces), true);
    repository.places.single.complete([]);
    await places;
    expect(model.loading, false);
  });

  test('late superseded completion publishes final loading state', () async {
    final first = model.refreshRecommendEvent(account: 'user');
    final second = model.refreshRecommendEvent(account: 'user');
    repository.events[1].complete([RecommendedEvent(id: 'new', name: 'new')]);
    await second;
    expect(model.loading, true);
    final observed = <bool>[];
    model.addListener(() => observed.add(model.loading));
    repository.events.first.complete([]);
    await first;
    expect(model.state.recommendEvents.single.id, 'new');
    expect(model.loading, false);
    expect(observed.last, false);
  });

  for (final fail in [false, true]) {
    test('old-account retry fail=$fail cannot update new state', () async {
      final pending = model.retrySection(
        section: DashboardSection.recommendEvents,
        account: 'user',
      );
      model.switchAccount('new');
      var updates = 0;
      model.addListener(() => updates++);
      if (fail) {
        repository.events.single.completeError(StateError('old failure'));
      } else {
        repository.events.single.complete([]);
      }
      await pending;
      expect(model.hasFailed(DashboardSection.recommendEvents), false);
      expect(model.loading, false);
      expect(updates, 0);
    });
  }

  test('older retry failure cannot replace a newer successful retry', () async {
    final first = model.retrySection(
      section: DashboardSection.recommendEvents,
      account: 'user',
    );
    final second = model.retrySection(
      section: DashboardSection.recommendEvents,
      account: 'user',
    );
    repository.events[1].complete([]);
    await second;
    repository.events[0].completeError(StateError('old failure'));
    await first;
    expect(model.hasFailed(DashboardSection.recommendEvents), false);
    expect(model.loading, false);
  });

  test('wrong-account and disposed retries never start a query', () async {
    await model.retrySection(
      section: DashboardSection.recommendEvents,
      account: 'wrong',
    );
    model.dispose();
    await model.retrySection(
      section: DashboardSection.recommendEvents,
      account: 'user',
    );
    expect(repository.events, isEmpty);
  });
}

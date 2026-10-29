import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/controller_dashboard.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/repository/repository_dashboard.dart';
import 'package:life_pilot/utils/provider_locale.dart';

class _Repository extends DashboardRepository {
  final writes = <({String id, String account, Completer<void> done})>[];
  void Function()? onWrite;
  @override
  Future<void> completeEvent({required String id, required String account}) {
    final done = Completer<void>();
    writes.add((id: id, account: account, done: done));
    onWrite?.call();
    return done.future;
  }
}

void main() {
  late _Repository repository;
  late ControllerDashboard controller;
  late ProviderLocale locale;
  setUp(() {
    repository = _Repository();
    locale = ProviderLocale(locale: const Locale('en'));
    controller = ControllerDashboard(
      repository: repository,
      localeProvider: locale,
    )..switchAccount('a');
    controller.addUpcomingEvent(
      CalendarEvent(id: 'event', name: 'Event', startDate: DateTime.now()),
      account: 'a',
    );
  });
  tearDown(() {
    if (!controller.notifierDisposed) controller.dispose();
    locale.dispose();
  });
  test('concurrent completion shares persistence and publishes once', () async {
    var notifications = 0;
    controller.addListener(() => notifications++);
    final first = controller.completeEvent(id: 'event', account: 'a');
    final second = controller.completeEvent(id: 'event', account: 'a');
    expect(second, same(first));
    expect(repository.writes.length, 1);
    repository.writes.single.done.complete();
    await first;
    expect(controller.state.todayEvents, isEmpty);
    expect(notifications, 1);
  });
  test('synchronous repository callback joins registered completion', () async {
    Future<void>? joined;
    repository.onWrite = () {
      joined = controller.completeEvent(id: 'event', account: 'a');
    };
    final first = controller.completeEvent(id: 'event', account: 'a');
    expect(joined, same(first));
    repository.writes.single.done.complete();
    await first;
  });
  test('failure preserves event and allows a new retry', () async {
    final first = controller.completeEvent(id: 'event', account: 'a');
    final checked = expectLater(first, throwsStateError);
    repository.writes.single.done.completeError(StateError('offline'));
    await checked;
    expect(controller.state.todayEvents.single.id, 'event');
    final retry = controller.completeEvent(id: 'event', account: 'a');
    expect(repository.writes.length, 2);
    repository.writes.last.done.complete();
    await retry;
    expect(controller.state.todayEvents, isEmpty);
  });
  test('different events persist independently', () async {
    final first = controller.completeEvent(id: 'event', account: 'a');
    final second = controller.completeEvent(id: 'other', account: 'a');
    expect(repository.writes.length, 2);
    for (final write in repository.writes) {
      write.done.complete();
    }
    await Future.wait([first, second]);
  });
  test('account round trip cannot join or publish old completion', () async {
    final old = controller.completeEvent(id: 'event', account: 'a');
    controller.switchAccount('b');
    controller.switchAccount('a');
    controller.addUpcomingEvent(
      CalendarEvent(id: 'event', name: 'New', startDate: DateTime.now()),
      account: 'a',
    );
    final fresh = controller.completeEvent(id: 'event', account: 'a');
    expect(repository.writes.length, 2);
    repository.writes.first.done.complete();
    await old;
    expect(controller.state.todayEvents.single.name, 'New');
    expect(controller.completeEvent(id: 'event', account: 'a'), same(fresh));
    repository.writes.last.done.complete();
    await fresh;
    expect(controller.state.todayEvents, isEmpty);
  });
  test('disposed and wrong-account calls do not send writes', () async {
    await controller.completeEvent(id: 'event', account: 'b');
    controller.dispose();
    await controller.completeEvent(id: 'event', account: 'a');
    expect(repository.writes, isEmpty);
  });
}

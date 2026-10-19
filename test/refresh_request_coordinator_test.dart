import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/refresh_request_coordinator.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late RefreshRequestCoordinator coordinator;
  late List<Completer<void>> requests;
  Future<void> read() {
    final request = Completer<void>();
    requests.add(request);
    return request.future;
  }

  setUp(() {
    coordinator = RefreshRequestCoordinator();
    requests = [];
  });

  test('ordinary callers share the active request', () async {
    final first = coordinator.run(read);
    final second = coordinator.run(read);
    expect(identical(first, second), isTrue);
    expect(requests.length, 1);
    expect(coordinator.isRunning, isTrue);
    requests.single.complete();
    await Future.wait([first, second]);
    expect(coordinator.isRunning, isFalse);
  });

  test('concurrent forced callers share exactly one follow-up read', () async {
    final first = coordinator.run(read);
    final forces = List.generate(10, (_) => coordinator.run(read, force: true));
    expect(forces.every((future) => identical(future, forces.first)), isTrue);
    expect(requests.length, 1);
    requests.first.complete();
    await first;
    await flush();
    expect(requests.length, 2);
    requests.last.complete();
    await Future.wait(forces);
    expect(coordinator.isRunning, isFalse);
  });

  test(
    'a new force during the follow-up schedules one more fresh read',
    () async {
      final first = coordinator.run(read);
      final second = coordinator.run(read, force: true);
      requests.first.complete();
      await first;
      await flush();
      final third = coordinator.run(read, force: true);
      final sharedThird = coordinator.run(read, force: true);
      expect(identical(third, sharedThird), isTrue);
      requests[1].complete();
      await second;
      await flush();
      expect(requests.length, 3);
      requests.last.complete();
      await Future.wait([third, sharedThird]);
    },
  );

  test('queued force retries after an active read fails', () async {
    final first = coordinator.run(read);
    final firstError = expectLater(first, throwsStateError);
    final retry = coordinator.run(read, force: true);
    requests.first.completeError(StateError('first failed'));
    await firstError;
    await flush();
    expect(requests.length, 2);
    requests.last.complete();
    await retry;
    expect(coordinator.isRunning, isFalse);
  });

  test('failed follow-up does not poison later reads', () async {
    final first = coordinator.run(read);
    final retry = coordinator.run(read, force: true);
    final retryError = expectLater(retry, throwsStateError);
    requests.first.complete();
    await first;
    await flush();
    requests[1].completeError(StateError('retry failed'));
    await retryError;
    final next = coordinator.run(read);
    expect(requests.length, 3);
    requests.last.complete();
    await next;
  });

  test('synchronous errors release the active request', () async {
    await expectLater(
      coordinator.run(() => throw StateError('sync')),
      throwsStateError,
    );
    expect(coordinator.isRunning, isFalse);
    final next = coordinator.run(read);
    requests.single.complete();
    await next;
  });

  test(
    'reentrant ordinary calls see the request before refresh starts',
    () async {
      Future<void>? nested;
      final first = coordinator.run(() {
        nested = coordinator.run(read);
        return Future<void>.value();
      });
      expect(identical(first, nested), isTrue);
      expect(requests, isEmpty);
      await first;
    },
  );

  test('separate coordinators never share requests', () async {
    final first = coordinator.run(read);
    final other = RefreshRequestCoordinator().run(read);
    expect(requests.length, 2);
    for (final request in requests) {
      request.complete();
    }
    await Future.wait([first, other]);
  });
}

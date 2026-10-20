import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/controller_page_calendar_add.dart';
import 'package:life_pilot/event/controller_page_event_add.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/controller_speech_input.dart';
import 'package:life_pilot/utils/service/service_speech.dart';

class _Auth extends ControllerAuth {
  @override
  String? get currentAccount => 'member@example.com';
}

class _Speech implements ServiceSpeech {
  final pending = <Completer<bool>>[];
  final callbacks = <ValueChanged<String>>[];
  final spoken = <String>[];
  int stops = 0;
  Completer<void>? stopping;

  @override
  Future<bool> startListening({required ValueChanged<String> onResult}) {
    callbacks.add(onResult);
    final result = Completer<bool>();
    pending.add(result);
    return result.future;
  }

  @override
  Future<void> stopListening() async {
    stops++;
    await stopping?.future;
  }

  @override
  Future<void> speakText({required String text}) async => spoken.add(text);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final table in [
    TableNames.calendarEvents,
    TableNames.recommendEvents,
    TableNames.recommendPlaces,
    TableNames.memoryTrace,
  ]) {
    group(table, () {
      late _Auth auth;
      late _Speech speech;
      late ControllerSpeechInput controller;
      setUp(() {
        auth = _Auth();
        speech = _Speech();
        controller = table == TableNames.calendarEvents
            ? ControllerPageCalendarAdd(
                auth: auth,
                tableName: table,
                serviceSpeech: speech,
              )
            : ControllerPageEventAdd(
                auth: auth,
                tableName: table,
                serviceSpeech: speech,
              );
      });
      tearDown(() async {
        if (!controller.notifierDisposed) controller.dispose();
        for (final pending in speech.pending) {
          if (!pending.isCompleted) pending.complete(false);
        }
        if (speech.stopping case final stopping? when !stopping.isCompleted) {
          stopping.complete();
        }
        await Future<void>.delayed(Duration.zero);
        auth.dispose();
      });

      test(
        'final result resets the microphone and is delivered exactly once',
        () async {
          final texts = <String>[];
          final start = controller.startListening(
            key: 'name',
            onResult: texts.add,
          );
          speech.pending.single.complete(true);
          await start;
          expect(controller.isListening, true);
          expect(controller.currentListeningKey, 'name');
          speech.callbacks.single('recognized');
          speech.callbacks.single('duplicate');
          expect(texts, ['recognized']);
          expect(controller.isListening, false);
          expect(controller.currentListeningKey, isNull);
        },
      );

      test(
        'leaving while starting stops speech and rejects disposed-field writes',
        () async {
          final text = TextEditingController();
          final start = controller.startListening(
            key: 'name',
            onResult: (value) => text.text = value,
          );
          controller.dispose();
          text.dispose();
          expect(speech.stops, 1);
          speech.callbacks.single('late');
          speech.pending.single.complete(true);
          await start;
          expect(controller.isListening, false);
          expect(controller.currentListeningKey, isNull);
        },
      );

      test(
        'stop before startup completes cannot relatch recording state',
        () async {
          final start = controller.startListening(
            key: 'name',
            onResult: (_) => fail('cancelled result'),
          );
          await controller.stopListening();
          speech.callbacks.single('late');
          speech.pending.single.complete(true);
          await start;
          expect(controller.isListening, false);
          expect(controller.currentListeningKey, isNull);
        },
      );

      test(
        'a newer target field wins over older startup and callback',
        () async {
          final first = controller.startListening(
            key: 'name',
            onResult: (_) => fail('old field'),
          );
          final texts = <String>[];
          final latest = controller.startListening(
            key: 'description',
            onResult: texts.add,
          );
          speech.pending[1].complete(true);
          await latest;
          speech.callbacks[0]('old');
          speech.pending[0].complete(true);
          await first;
          expect(controller.isListening, true);
          expect(controller.currentListeningKey, 'description');
          speech.callbacks[1]('new');
          expect(texts, ['new']);
        },
      );

      test('an older pending stop cannot clear a new target field', () async {
        final first = controller.startListening(key: 'name', onResult: (_) {});
        speech.pending[0].complete(true);
        await first;
        speech.stopping = Completer<void>();
        final stop = controller.stopListening();
        expect(controller.isListening, false);
        final latest = controller.startListening(
          key: 'description',
          onResult: (_) {},
        );
        speech.pending[1].complete(true);
        await latest;
        speech.stopping!.complete();
        await stop;
        expect(controller.isListening, true);
        expect(controller.currentListeningKey, 'description');
      });

      test(
        'a fast final result during startup does not reactivate the microphone',
        () async {
          final texts = <String>[];
          final start = controller.startListening(
            key: 'name',
            onResult: texts.add,
          );
          speech.callbacks.single('fast');
          speech.pending.single.complete(true);
          await start;
          expect(texts, ['fast']);
          expect(controller.isListening, false);
          expect(controller.currentListeningKey, isNull);
        },
      );

      test('unavailable speech is inactive and can be retried', () async {
        final first = controller.startListening(key: 'name', onResult: (_) {});
        speech.pending[0].complete(false);
        await first;
        expect(controller.isListening, false);
        expect(controller.currentListeningKey, isNull);
        final retry = controller.startListening(key: 'name', onResult: (_) {});
        speech.pending[1].complete(true);
        await retry;
        expect(controller.isListening, true);
      });

      test(
        'disposed forms start no new recording or text-to-speech work',
        () async {
          await controller.speakText(text: 'Read this');
          expect(speech.spoken, ['Read this']);
          controller.dispose();
          await controller.speakText(text: 'Do not read');
          await controller.startListening(
            key: 'name',
            onResult: (_) => fail('disposed'),
          );
          await controller.stopListening();
          expect(speech.pending, isEmpty);
          expect(speech.spoken, ['Read this']);
          expect(speech.stops, 1);
        },
      );

      test('a result may close the form without a late notification', () async {
        var notifications = 0;
        controller.addListener(() => notifications++);
        final start = controller.startListening(
          key: 'name',
          onResult: (_) => controller.dispose(),
        );
        speech.callbacks.single('done');
        speech.pending.single.complete(true);
        await start;
        expect(controller.notifierDisposed, true);
        expect(notifications, 0);
      });
    });
  }

  test(
    'an unused form can stop and dispose without initializing native speech',
    () async {
      final controller = ControllerSpeechInput();
      await controller.stopListening();
      await controller.speakText(text: '');
      controller.dispose();
      expect(controller.notifierDisposed, true);
    },
  );
}

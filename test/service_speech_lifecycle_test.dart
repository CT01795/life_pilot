import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/service/service_speech.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

class _Speech implements stt.SpeechToText {
  final initializations = <Completer<bool>>[];
  final listens = <Completer<void>>[];
  final callbacks = <void Function(SpeechRecognitionResult)>[];
  final options = <stt.SpeechListenOptions>[];
  int stops = 0;
  bool throwInitialize = false;
  Completer<void>? stopResult;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #initialize) {
      if (throwInitialize) {
        throwInitialize = false;
        throw StateError('microphone unavailable');
      }
      final result = Completer<bool>();
      initializations.add(result);
      return result.future;
    }
    if (invocation.memberName == #listen) {
      final result = Completer<void>();
      listens.add(result);
      callbacks.add(
        invocation.namedArguments[#onResult]
            as void Function(SpeechRecognitionResult),
      );
      options.add(
        invocation.namedArguments[#listenOptions] as stt.SpeechListenOptions,
      );
      return result.future;
    }
    if (invocation.memberName == #stop) {
      stops++;
      return stopResult?.future ?? Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _Tts implements FlutterTts {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #setCompletionHandler) return null;
    return super.noSuchMethod(invocation);
  }
}

SpeechRecognitionResult result(String text, {bool finalResult = true}) =>
    SpeechRecognitionResult.init([
      SpeechRecognitionWords(text, null, 1),
    ], finalResult ? ResultType.finalResult : ResultType.partial);

void main() {
  late _Speech speech;
  late ServiceSpeech service;
  setUp(() {
    speech = _Speech();
    service = ServiceSpeech(speech: speech, tts: _Tts());
  });
  Future<void> ready() async {
    final pending = service.initialize();
    speech.initializations.last.complete(true);
    expect(await pending, true);
  }

  test(
    'concurrent initialization is shared and successful setup is reused',
    () async {
      final first = service.initialize();
      final others = List.generate(8, (_) => service.initialize());
      expect(others.every((future) => identical(future, first)), true);
      expect(speech.initializations.length, 1);
      speech.initializations.single.complete(true);
      expect(await first, true);
      await Future.wait(others);
      expect(await service.initialize(), true);
      expect(speech.initializations.length, 1);
    },
  );

  test('denied initialization can be retried', () async {
    final first = service.initialize();
    speech.initializations.single.complete(false);
    expect(await first, false);
    await ready();
    expect(speech.initializations.length, 2);
  });

  test(
    'synchronous initialization failure does not poison retry state',
    () async {
      speech.throwInitialize = true;
      expect(await service.initialize(), false);
      expect(service.isInitialized, false);
      await ready();
    },
  );

  test(
    'asynchronous initialization failure is handled and retryable',
    () async {
      final first = service.initialize();
      speech.initializations.single.completeError(
        StateError('permission failed'),
      );
      expect(await first, false);
      await ready();
    },
  );

  test(
    'start waits for native setup and catches asynchronous listen failure',
    () async {
      await ready();
      final pending = service.startListening(onResult: (_) {});
      var completed = false;
      pending.then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(completed, false);
      expect(speech.options.single.listenMode, stt.ListenMode.confirmation);
      expect(speech.options.single.partialResults, false);
      expect(speech.options.single.cancelOnError, true);
      speech.listens.single.completeError(StateError('native start failed'));
      expect(await pending, false);
      expect(service.isListening, false);
    },
  );

  test(
    'stop while permission is pending prevents microphone startup',
    () async {
      final pending = service.startListening(
        onResult: (_) => fail('late result'),
      );
      await service.stopListening();
      speech.initializations.single.complete(true);
      expect(await pending, false);
      expect(speech.listens, isEmpty);
      expect(speech.stops, 0);
    },
  );

  test(
    'concurrent starts during initialization only activate newest request',
    () async {
      final first = service.startListening(
        onResult: (_) => fail('superseded result'),
      );
      final latest = service.startListening(onResult: (_) {});
      expect(speech.initializations.length, 1);
      speech.initializations.single.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(speech.listens.length, 1);
      speech.listens.single.complete();
      expect(await first, false);
      expect(await latest, true);
      await service.stopListening();
    },
  );

  test('only one final result is delivered, then recording stops', () async {
    await ready();
    final texts = <String>[];
    final pending = service.startListening(onResult: texts.add);
    speech.listens.single.complete();
    expect(await pending, true);
    speech.callbacks.single(result('partial', finalResult: false));
    speech.callbacks.single(result('final'));
    speech.callbacks.single(result('duplicate final'));
    expect(texts, ['final']);
    expect(service.isListening, false);
    expect(speech.stops, 1);
  });

  test(
    'a final result during native startup cannot leave recording active',
    () async {
      await ready();
      final texts = <String>[];
      final pending = service.startListening(onResult: texts.add);
      speech.callbacks.single(result('quick final'));
      speech.listens.single.complete();
      expect(await pending, false);
      expect(texts, ['quick final']);
      expect(service.isListening, false);
      expect(speech.stops, 1);
    },
  );

  test('manual stop immediately ignores late callbacks', () async {
    await ready();
    final texts = <String>[];
    final pending = service.startListening(onResult: texts.add);
    speech.listens.single.complete();
    await pending;
    speech.stopResult = Completer<void>();
    final stopping = service.stopListening();
    expect(service.isListening, false);
    speech.callbacks.single(result('late'));
    expect(texts, isEmpty);
    speech.stopResult!.completeError(StateError('stop failed'));
    await stopping;
    expect(service.isListening, false);
  });

  test('an old stop failure cannot reset a newly started session', () async {
    await ready();
    final old = service.startListening(onResult: (_) {});
    speech.listens[0].complete();
    await old;
    speech.stopResult = Completer<void>();
    final stopping = service.stopListening();
    final latest = service.startListening(onResult: (_) {});
    speech.listens[1].complete();
    expect(await latest, true);
    speech.stopResult!.completeError(StateError('old stop failed'));
    await stopping;
    expect(service.isListening, true);
    speech.stopResult = null;
    await service.stopListening();
  });

  test(
    'old callbacks and late start errors do not reset a new session',
    () async {
      await ready();
      final texts = <String>[];
      final old = service.startListening(onResult: (_) => fail('stale'));
      final latest = service.startListening(onResult: texts.add);
      speech.listens[1].complete();
      expect(await latest, true);
      speech.callbacks[0](result('old'));
      speech.listens[0].completeError(StateError('old start failed'));
      expect(await old, false);
      expect(service.isListening, true);
      speech.callbacks[1](result('new'));
      expect(texts, ['new']);
    },
  );

  test(
    'a final-result handler can start a new session without it being stopped',
    () async {
      await ready();
      Future<bool>? restarted;
      final old = service.startListening(
        onResult: (_) {
          restarted = service.startListening(onResult: (_) {});
        },
      );
      speech.listens[0].complete();
      await old;
      speech.callbacks[0](result('first'));
      expect(speech.listens.length, 2);
      expect(speech.stops, 0);
      speech.listens[1].complete();
      expect(await restarted!, true);
      expect(service.isListening, true);
      await service.stopListening();
    },
  );
}

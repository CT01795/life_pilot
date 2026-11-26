import 'package:flutter/foundation.dart';
import 'package:life_pilot/game/google_tts_audio.dart';
import 'package:life_pilot/utils/service/service_speech.dart';
import 'package:life_pilot/utils/tts/native_speech.dart';
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:life_pilot/game/translation/service_translation_speech.dart';

class _Tts implements FlutterTts {
  final calls = <Invocation>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    return Future<dynamic>.value(1);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    test(
      '$platform speaks translation questions and answers natively',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final tts = _Tts();
        final service = ServiceTranslationSpeech(tts: tts);
        final cases = [
          ('中翻英', true, 'zh-TW'),
          ('中翻英', false, 'en-US'),
          ('英翻中', true, 'en-US'),
          ('英翻中', false, 'zh-TW'),
          ('日翻中', true, 'ja-JP'),
          ('中翻日', false, 'ja-JP'),
          ('韓翻中', true, 'ko-KR'),
          ('中翻韓', false, 'ko-KR'),
        ];
        for (final (group, isQuestion, language) in cases) {
          await service.speak('hello / alternative', group, isQuestion);
          expect(
            tts.calls
                .where((c) => c.memberName == #setLanguage)
                .last
                .positionalArguments
                .single,
            language,
          );
          expect(
            tts.calls
                .where((c) => c.memberName == #speak)
                .last
                .positionalArguments
                .single,
            'hello',
          );
        }
        final categories = tts.calls.where(
          (c) => c.memberName == #setIosAudioCategory,
        );
        if (platform == TargetPlatform.iOS) {
          expect(categories.length, cases.length);
          expect(
            categories.first.positionalArguments.first,
            IosTextToSpeechAudioCategory.playback,
          );
        } else {
          expect(categories, isEmpty);
        }
        await service.dispose();
        final count = tts.calls.length;
        await service.speak('after disposal', '中翻英', true);
        expect(tts.calls.length, count);
      },
    );
  }

  test('rapid question changes speak only the latest request', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final tts = _Tts();
    final service = ServiceTranslationSpeech(tts: tts);
    await Future.wait([
      service.speak('old', '英翻中', true),
      service.speak('new', '英翻中', true),
    ]);
    expect(
      tts.calls
          .where((c) => c.memberName == #speak)
          .map((c) => c.positionalArguments.single),
      ['new'],
    );
    await service.dispose();
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    test('$platform shared game audio never downloads remote speech', () async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final tts = _Tts();
      final audio = GoogleTtsAudio(
        tts: tts,
        client: MockClient((_) async => throw StateError('network forbidden')),
      );
      await audio.speak(text: 'こんにちは', languageCode: 'ja');
      expect(
        tts.calls
            .where((c) => c.memberName == #speak)
            .single
            .positionalArguments
            .single,
        'こんにちは',
      );
      expect(
        tts.calls
            .where((c) => c.memberName == #setLanguage)
            .single
            .positionalArguments
            .single,
        'ja-JP',
      );
      await audio.dispose();
    });

    test(
      '$platform form read-aloud uses the shared playback settings',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final tts = _Tts();
        final speech = ServiceSpeech(tts: tts);
        await speech.speakText(text: '今天 1/2 的行程');
        expect(
          tts.calls
              .where((c) => c.memberName == #speak)
              .single
              .positionalArguments
              .single,
          '今天 1/2 的行程',
        );
        expect(
          tts.calls
              .where((c) => c.memberName == #setLanguage)
              .single
              .positionalArguments
              .single,
          'zh-TW',
        );
        expect(
          tts.calls
              .where((c) => c.memberName == #setVolume)
              .single
              .positionalArguments
              .single,
          1.0,
        );
        await speech.stopSpeaking();
      },
    );
  }

  test('language detection supports Chinese English Japanese and Korean', () {
    expect(speechLanguageForText('今天的行程'), 'zh-TW');
    expect(speechLanguageForText('Hello'), 'en-US');
    expect(speechLanguageForText('こんにちは'), 'ja-JP');
    expect(speechLanguageForText('안녕하세요'), 'ko-KR');
  });
}

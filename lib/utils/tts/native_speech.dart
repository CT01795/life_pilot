import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Shared native playback for game prompts and text read-aloud controls.
class NativeSpeech {
  NativeSpeech({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  Future<void> _queue = Future<void>.value();
  int _generation = 0;
  bool _disposed = false;

  Future<void> speak(String text, {required String languageCode}) async {
    final spokenText = text.trim();
    if (_disposed || spokenText.isEmpty) return;
    final generation = ++_generation;
    final request = _queue.then((_) async {
      if (_disposed || generation != _generation) return;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ], IosTextToSpeechAudioMode.spokenAudio);
      }
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(false);
      await _tts.stop();
      if (_disposed || generation != _generation) return;
      await _tts.setLanguage(switch (languageCode) {
        'zh' => 'zh-TW',
        'ja' => 'ja-JP',
        'ko' => 'ko-KR',
        _ => languageCode,
      });
      if (_disposed || generation != _generation) return;
      await _tts.speak(spokenText);
    });
    // A failed utterance must not poison later playback requests.
    _queue = request.catchError((Object _) {});
    await request;
  }

  Future<void> stop() async {
    _generation++;
    await _queue;
    await _tts.stop();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
  }
}

String speechLanguageForText(String text) {
  if (RegExp(r'[\u3040-\u30ff]').hasMatch(text)) return 'ja-JP';
  if (RegExp(r'[\uac00-\ud7af]').hasMatch(text)) return 'ko-KR';
  if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) return 'zh-TW';
  return 'en-US';
}

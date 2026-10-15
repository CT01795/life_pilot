import 'package:flutter/foundation.dart';
import 'package:life_pilot/game/google_tts_audio.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/tts/tts_stub.dart'
    if (dart.library.html) 'package:life_pilot/utils/tts/tts_web.dart';

/// Owns platform selection and lazy audio resources, not game state or widgets.
class ServiceGameSpeech {
  GoogleTtsAudio? _audio;
  bool _disposed = false;
  static final _chinese = RegExp(r'[\u4e00-\u9fff]');

  Future<void> speak(String text) async {
    await _speak(text);
  }

  /// Grammar exercises use English on native devices, regardless of UI locale.
  Future<void> speakEnglish(String text) async {
    await _speak(text, nativeLanguage: 'en-US');
  }

  Future<void> _speak(String text, {String? nativeLanguage}) async {
    if (_disposed || text.isEmpty) return;
    try {
      if (kIsWeb) {
        await speakWeb(text);
      } else {
        final audio = _audio ??= GoogleTtsAudio();
        await audio.speak(
          text: text,
          languageCode:
              nativeLanguage ?? (_chinese.hasMatch(text) ? 'zh' : 'en-US'),
        );
      }
    } catch (error, stackTrace) {
      logger.e('Game audio failed', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final audio = _audio;
    _audio = null;
    try {
      await audio?.dispose();
    } catch (error, stackTrace) {
      logger.e(
        'Dispose game audio failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

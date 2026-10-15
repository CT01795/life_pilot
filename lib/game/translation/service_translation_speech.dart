import 'package:flutter/foundation.dart';
import 'package:life_pilot/game/google_tts_audio.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/tts/tts_stub.dart'
    if (dart.library.html) 'package:life_pilot/utils/tts/tts_web.dart';

/// Owns platform audio resources; translation direction stays independent of UI locale.
class ServiceTranslationSpeech {
  GoogleTtsAudio? _audio;
  bool _disposed = false;
  Future<void> _speak(String text, String group, bool isQuestion) async {
    if (_disposed || text.isEmpty) return;

    if (kIsWeb) {
      await speakWeb(text, group: group, isQuestion: isQuestion);
      return;
    }

    var languageCode = 'en-US';
    if ((group.contains('中翻英') && isQuestion) ||
        (group.contains('英翻中') && !isQuestion) ||
        (group.contains('日翻中') && !isQuestion) ||
        (group.contains('中翻日') && isQuestion) ||
        (group.contains('韓翻中') && !isQuestion) ||
        (group.contains('中翻韓') && isQuestion)) {
      languageCode = 'zh';
    } else if ((group.contains('中翻日') && !isQuestion) ||
        (group.contains('日翻中') && isQuestion)) {
      languageCode = 'ja';
    } else if ((group.contains('中翻韓') && !isQuestion) ||
        (group.contains('韓翻中') && isQuestion)) {
      languageCode = 'ko';
    }

    final audio = _audio ??= GoogleTtsAudio();
    await audio.speak(text: text, languageCode: languageCode);
  }

  Future<void> speak(String text, String group, bool isQuestion) async {
    try {
      await _speak(text, group, isQuestion);
    } catch (error, stackTrace) {
      logger.e(
        'Translation audio failed',
        error: error,
        stackTrace: stackTrace,
      );
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
        'Dispose translation audio failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

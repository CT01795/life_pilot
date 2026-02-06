import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

class ControllerAccountingSpeech {
  
  final SpeechService _speechService = SpeechService();

  Future<String> recordAndTranscribe() async {
    return await _speechService.listenOnce();
  }
}

class SpeechService {
  final SpeechToText _speech = SpeechToText();

  Future<String> listenOnce() async {
    if (!await _speech.initialize()) return '';

    final completer = Completer<String>();
    
    await _speech.listen(
      localeId: 'zh_TW',
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation, // ✅ 新位置
        partialResults: false, // 減少亂跳
        cancelOnError: true,
      ),
      onResult: (result) {
        if (result.finalResult && !completer.isCompleted) {
          completer.complete(result.recognizedWords);
          _speech.stop();
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () {
        _speech.stop();
        return '';
      },
    );
  }
}

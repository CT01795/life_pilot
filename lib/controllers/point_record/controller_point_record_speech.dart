import 'package:speech_to_text/speech_to_text.dart';

class ControllerPointRecordSpeech {
  
  final SpeechService _speechService = SpeechService();

  Future<String> recordAndTranscribe() async {
    return await _speechService.listenOnce();
  }
}

class SpeechService {
  final SpeechToText _speech = SpeechToText();

  Future<String> listenOnce() async {
    final available = await _speech.initialize();
    if (!available) return '';

    String resultText = '';

    await _speech.listen(
      localeId: 'zh_TW',
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation, // ✅ 新位置
        partialResults: false, // 減少亂跳
        cancelOnError: true,
      ),
      onResult: (result) {
        if (result.finalResult) {
          resultText = result.recognizedWords;
        }
      },
    );

    // 最多聽 5 秒
    await Future.delayed(const Duration(seconds: 5));
    await _speech.stop();

    return resultText;
  }
}

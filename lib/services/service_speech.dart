import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ServiceSpeech {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  Future<void> speakText({required String text}) async {
    if (text.isNotEmpty) {
      await _tts.stop();
      await _tts.speak(text);
    }
  }

  Future<bool> startListening(
      {required ValueChanged<String> onResult, required String key}) async {
    bool available = await _speech.initialize();
    if (!available) return false;

    _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
      ),
    );
    return true;
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }
}

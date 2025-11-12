import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/logger.dart';

class ServiceSpeech {
  final stt.SpeechToText _speech;
  final FlutterTts _tts;

  bool _initialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;

  ServiceSpeech({stt.SpeechToText? speech, FlutterTts? tts})
      : _speech = speech ?? stt.SpeechToText(),
        _tts = tts ?? FlutterTts();

  // 狀態暴露
  bool get isInitialized => _initialized;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;

  // 初始化 SpeechToText
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      _initialized = await _speech.initialize();
    } catch (e, st) {
      _initialized = false;
      logger.e("STT initialize error", error: e, stackTrace: st);
    }
    return _initialized;
  }

  Future<void> speakText({required String text}) async {
    if (text.isEmpty) return;

    try {
      if (_isSpeaking) await _tts.stop();
      _isSpeaking = true;
      await _tts.speak(text);
    } catch (e, st) {
      logger.e("TTS speak error", error: e, stackTrace: st);
    } finally {
      _isSpeaking = false;
    }
  }

  Future<bool> startListening(
      {required ValueChanged<String> onResult}) async {
    if (!_initialized && !await initialize()) return false;
    
    try {
      _isListening = true;
      _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
        ),
      );
      return true;
    } catch (e, st) {
      logger.e("STT listen error", error: e, stackTrace: st);
      _isListening = false;
      return false;
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    try {
      await _speech.stop();
    } catch (e, st) {
      logger.e("STT stop error", error: e, stackTrace: st);
    } finally {
      _isListening = false;
    }
  }
}

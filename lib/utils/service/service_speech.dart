import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../logger.dart';

class ServiceSpeech {
  final stt.SpeechToText _speech;
  final FlutterTts _tts;

  bool _initialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  Future<bool>? _initialization;
  int _listeningGeneration = 0;

  ServiceSpeech({stt.SpeechToText? speech, FlutterTts? tts})
    : _speech = speech ?? stt.SpeechToText(),
      _tts = tts ?? FlutterTts() {
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });
  }

  // 狀態暴露
  bool get isInitialized => _initialized;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;

  // 初始化 SpeechToText
  Future<bool> initialize() {
    if (_initialized) return Future.value(true);
    final active = _initialization;
    if (active != null) return active;
    final completion = Completer<bool>();
    _initialization = completion.future;
    unawaited(_initializeSpeech(completion));
    return completion.future;
  }

  Future<void> _initializeSpeech(Completer<bool> completion) async {
    try {
      _initialized = await _speech.initialize();
    } catch (e, st) {
      _initialized = false;
      logger.e("STT initialize error", error: e, stackTrace: st);
    } finally {
      _initialization = null;
      completion.complete(_initialized);
    }
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

  Future<bool> startListening({required ValueChanged<String> onResult}) async {
    final generation = ++_listeningGeneration;
    if (!_initialized && !await initialize()) return false;
    if (generation != _listeningGeneration) return false;
    var delivered = false;

    try {
      _isListening = true;
      await _speech.listen(
        onResult: (result) {
          if (generation != _listeningGeneration ||
              !_isListening ||
              delivered ||
              !result.finalResult) {
            return;
          }
          delivered = true;
          try {
            onResult(result.recognizedWords);
          } finally {
            // A result handler may start another recording. Do not stop it.
            if (generation == _listeningGeneration) {
              unawaited(stopListening());
            }
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          partialResults: false,
          cancelOnError: true,
        ),
      );
      // Do not let callers mark the microphone active after a final result
      // already ended this session while native startup was still pending.
      return generation == _listeningGeneration && _isListening;
    } catch (e, st) {
      logger.e("STT listen error", error: e, stackTrace: st);
      if (generation == _listeningGeneration) _isListening = false;
      return false;
    }
  }

  Future<void> stopListening() async {
    // Invalidate immediately, even while microphone permission is pending.
    _listeningGeneration++;
    final wasListening = _isListening;
    _isListening = false;
    if (!wasListening) return;
    try {
      await _speech.stop();
    } catch (e, st) {
      logger.e("STT stop error", error: e, stackTrace: st);
    }
  }
}

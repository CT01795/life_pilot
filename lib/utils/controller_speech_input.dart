import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/utils/service/service_speech.dart';

/// Shared form state. The service owns native speech operations; forms own
/// the destination field and must reject results after stopping or leaving.
class ControllerSpeechInput extends SafeChangeNotifier {
  ControllerSpeechInput({ServiceSpeech? serviceSpeech})
    : _speechService = serviceSpeech;

  ServiceSpeech? _speechService;
  ServiceSpeech get _speech => _speechService ??= ServiceSpeech();
  int _speechRequest = 0;
  bool _isListening = false;
  String? _currentListeningKey;

  bool get isListening => _isListening;
  String? get currentListeningKey => _currentListeningKey;

  bool _isCurrent(int request) =>
      !notifierDisposed && request == _speechRequest;

  Future<void> startListening({
    required ValueChanged<String> onResult,
    required String key,
  }) async {
    if (notifierDisposed) return;
    final request = ++_speechRequest;
    var delivered = false;
    final available = await _speech.startListening(
      onResult: (text) {
        if (!_isCurrent(request) || delivered) return;
        delivered = true;
        _isListening = false;
        _currentListeningKey = null;
        onResult(text);
        if (_isCurrent(request)) notifyListeners();
      },
    );
    if (!_isCurrent(request) || delivered) return;
    _isListening = available;
    _currentListeningKey = available ? key : null;
    notifyListeners();
  }

  Future<void> stopListening() async {
    if (notifierDisposed) return;
    _speechRequest++;
    _isListening = false;
    _currentListeningKey = null;
    final stopping = _speechService?.stopListening();
    notifyListeners();
    // Do not create the native service just to stop an unused form.
    await stopping;
  }

  Future<void> speakText({required String text}) async {
    if (notifierDisposed || text.isEmpty) return;
    await _speech.speakText(text: text);
  }

  @override
  void dispose() {
    _speechRequest++;
    _isListening = false;
    _currentListeningKey = null;
    super.dispose();
    final service = _speechService;
    if (service != null) unawaited(service.stopListening());
  }
}

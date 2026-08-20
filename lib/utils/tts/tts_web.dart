// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

final Set<String> _activeSpeech = {};

Future<void> _speakOnce(
  html.SpeechSynthesisUtterance utterance,
  String text,
) async {
  if (!_activeSpeech.add(text)) return;
  final synthesis = html.window.speechSynthesis;
  if (synthesis == null) {
    _activeSpeech.remove(text);
    return;
  }

  try {
    final speechFinished = Future.any<void>([
      utterance.onEnd.first,
      utterance.onError.first,
      Future<void>.delayed(const Duration(minutes: 2)),
    ]);
    synthesis.speak(utterance);
    await speechFinished;
  } finally {
    _activeSpeech.remove(text);
  }
}

Future<void> speakWeb(String text, {String? group, bool? isQuestion}) async {
  final utterance = html.SpeechSynthesisUtterance(text.split('/').first.trim());

  if (group == null || isQuestion == null) {
    utterance.lang =
        RegExp(r'[\u4e00-\u9fff]').hasMatch(text) ? 'zh-TW' : 'en-US';
    await _speakOnce(utterance, utterance.text ?? text);
    return;
  }
  // 判斷語言
  if ((group.contains("中翻英") && isQuestion) ||
      (group.contains("英翻中") && !isQuestion) ||
      (group.contains("日翻中") && !isQuestion) ||
      (group.contains("中翻日") && isQuestion) ||
      (group.contains("韓翻中") && !isQuestion) ||
      (group.contains("中翻韓") && isQuestion)) {
    utterance.lang = 'zh-TW';
  } else if ((group.contains("中翻日英") && !isQuestion) ||
      (group.contains("日翻中英") && isQuestion)) {
    utterance.lang = 'en-US';
  } else if ((group.contains("中翻日") && !isQuestion) ||
      (group.contains("日翻中") && isQuestion)) {
    utterance.lang = 'ja-JP';
  } else if ((group.contains("中翻韓英") && !isQuestion) ||
      (group.contains("韓翻中英") && isQuestion)) {
    utterance.lang = 'en-US';
  } else if ((group.contains("中翻韓") && !isQuestion) ||
      (group.contains("韓翻中") && isQuestion)) {
    utterance.lang = 'ko-KR';
  } else {
    utterance.lang = 'en-US';
  }

  await _speakOnce(utterance, utterance.text ?? text);
}

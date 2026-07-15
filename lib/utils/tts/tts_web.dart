// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

Future<void> speakWeb(String text, {String? group, bool? isQuestion}) async {
  final utterance = html.SpeechSynthesisUtterance(text.split('/').first.trim());

  if (group == null || isQuestion == null) {
    utterance.lang =
        RegExp(r'[\u4e00-\u9fff]').hasMatch(text) ? 'zh-TW' : 'en-US';
    html.window.speechSynthesis?.speak(utterance);
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
  } else if ((group.contains("中翻日") && !isQuestion) ||
      (group.contains("日翻中") && isQuestion)) {
    utterance.lang = 'ja-JP';
  } else if ((group.contains("中翻韓") && !isQuestion) ||
      (group.contains("韓翻中") && isQuestion)) {
    utterance.lang = 'ko-KR';
  } else {
    utterance.lang = 'en-US';
  }

  html.window.speechSynthesis?.speak(utterance);
}

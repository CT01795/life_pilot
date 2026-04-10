// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

Future<void> speakWeb(String text) async {
  final utterance = html.SpeechSynthesisUtterance(text.split('/').first.trim());

  // 判斷語言
  utterance.lang =
      RegExp(r'[\u4e00-\u9fff]').hasMatch(text) ? 'zh-TW' : 'en-US';

  html.window.speechSynthesis?.speak(utterance);
}
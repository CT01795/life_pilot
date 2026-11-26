// Run via tool/test_android_plugins.sh to retain the installed app and its data.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native timezone and preferences survive a round trip', (
    tester,
  ) async {
    final timezone = await FlutterTimezone.getLocalTimezone();
    expect(timezone.identifier, isNotEmpty);
    final prefs = await SharedPreferences.getInstance();
    final key =
        '__life_pilot_kotlin_smoke_${DateTime.now().microsecondsSinceEpoch}';
    try {
      expect(await prefs.setString(key, 'migration-ok'), isTrue);
      await prefs.reload();
      expect(prefs.getString(key), 'migration-ok');
    } finally {
      await prefs.remove(key);
    }
  });

  testWidgets('native TTS can complete an utterance', (tester) async {
    final tts = FlutterTts();
    try {
      final languages = List<String>.from(await tts.getLanguages as List);
      expect(
        languages,
        isNotEmpty,
        reason: 'The device needs a TTS voice installed.',
      );
      await tts.setLanguage(
        languages.contains('en-US') ? 'en-US' : languages.first,
      );
      await tts.awaitSpeakCompletion(true);
      expect(
        await tts
            .speak('Life Pilot audio test')
            .timeout(const Duration(seconds: 20)),
        1,
      );
    } finally {
      await tts.stop();
    }
  });

  testWidgets('audioplayers completes an in-memory WAV', (tester) async {
    final player = AudioPlayer();
    try {
      final completed = player.onPlayerComplete.first;
      await player.setVolume(0.2);
      await player.play(BytesSource(_testTone(), mimeType: 'audio/wav'));
      await completed.timeout(const Duration(seconds: 15));
    } finally {
      await player.dispose();
    }
  });

  testWidgets('WebView loads local content and executes JavaScript', (
    tester,
  ) async {
    final ready = Completer<void>();
    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.addJavaScriptChannel(
      'MigrationBridge',
      onMessageReceived: (message) {
        if (message.message == 'ready' && !ready.isCompleted) ready.complete();
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WebViewWidget(controller: controller)),
      ),
    );
    await controller.loadHtmlString(
      '<html><body>Plugin migration test<script>MigrationBridge.postMessage("ready")</script></body></html>',
    );
    await tester.runAsync(
      () => ready.future.timeout(const Duration(seconds: 20)),
    );
    expect(
      (await controller.runJavaScriptReturningResult('1 + 1')).toString(),
      '2',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Uint8List _testTone() {
  const sampleRate = 16000;
  const samples = 3200;
  final bytes = ByteData(44 + samples * 2);
  void tag(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  bytes.setUint32(4, 36 + samples * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  bytes.setUint32(40, samples * 2, Endian.little);
  for (var i = 0; i < samples; i++) {
    bytes.setInt16(
      44 + i * 2,
      (1200 * math.sin(2 * math.pi * 440 * i / sampleRate)).round(),
      Endian.little,
    );
  }
  return bytes.buffer.asUint8List();
}

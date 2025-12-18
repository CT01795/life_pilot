import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/game/controller_game_speaking.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/logger.dart';
import 'package:life_pilot/services/game/service_game_speaking.dart';
import 'package:provider/provider.dart';

// ignore: must_be_immutable
class PageGameSpeaking extends StatefulWidget {
  final String gameId;
  int? gameLevel;
  PageGameSpeaking({super.key, required this.gameId, this.gameLevel});

  @override
  State<PageGameSpeaking> createState() => _PageGameSpeakingState();
}

class _PageGameSpeakingState extends State<PageGameSpeaking> {
  late final ControllerGameSpeaking controller;
  bool _hasPopped = false; // 旗標，避免重複 pop
  final FlutterTts flutterTts = FlutterTts(); // TTS 實例
  double size = 32.0;
  int answeredCount = 0; // 紀錄答了幾題
  late int maxQ;
  bool isRecording = false;
  int repeatCounts = 0;

  @override
  void initState() {
    super.initState();

    final auth = context.read<ControllerAuth>();
    maxQ = widget.gameLevel != null ? min(widget.gameLevel! * 2, 10) : 10;
    controller = ControllerGameSpeaking(
      gameId: widget.gameId,
      userName: auth.currentAccount ?? AuthConstants.guest,
      service: ServiceGameSpeaking(),
    );

    controller.loadNextQuestion();
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  // 呼叫這個方法答題並判斷是否完成題數
  void onAnswer() {
    final userAnswer = constEmpty;
    repeatCounts++;
    repeatCounts = controller.answer(userAnswer, repeatCounts);

    if (widget.gameLevel != null && answeredCount >= maxQ && !_hasPopped) {
      _hasPopped = true;
      // 延遲一下讓 UI 更新後再跳回
      Future.microtask(() => Navigator.pop(context, true));
    }
  }

  Future<void> speak(String text) async {
    try {
      // 不 await stop，避免阻塞
      flutterTts.stop();
    } catch (e, st) {
      logger.e(e.toString() + st.toString());
    }
    final containsChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
    if (containsChinese) {
      await flutterTts.setLanguage("zh-TW");
      await flutterTts.setSpeechRate(0.4); // 🟢 中文語速（超重要）
      await flutterTts.setVolume(1.0); // 中文預設會比較小聲 → 拉滿
      flutterTts.speak(text.split('/')[0]); // 🔹 不 await，直接播放
    } else {
      await flutterTts.setLanguage("en-US");
      await flutterTts.setSpeechRate(0.6); // 🟢 英文語速
      await flutterTts.setVolume(1.0);
      flutterTts.speak(text.split('/')[0]); // 🔹 不 await，直接播放
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isFinished && !_hasPopped) {
          _hasPopped = true;
          Future.microtask(() => Navigator.pop(context, true));
          return Scaffold(
            body: Center(
              child: Text("Congratulations! Score: ${controller.score}"),
            ),
          );
        }

        if (controller.isLoading || controller.currentQuestion == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: Color(0xFFF5F7FA),
          appBar: AppBar(
            backgroundColor: Color(0xFF4DB6AC),
            title: Text("Speaking (${controller.score}/100)"),
          ),
          body: Column(
            children: [
              // 第一列：喇叭按鈕 + 題目
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.volume_up,
                          size: 50, color: Color(0xFF26A69A)),
                      onPressed: () =>
                          speak(controller.currentQuestion!.correctAnswer),
                    ),
                    Gaps.w8,
                    Flexible(
                      child: Text(
                        controller.currentQuestion!.question,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              Gaps.h16,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        !isRecording ? Icons.mic_none : Icons.stop, // 錄音時顯示停止
                        size: 50,
                        color: !isRecording ? Color(0xFF26A69A) : Colors.red,
                      ),
                      onPressed: () async {
                        if (!isRecording) {
                          // 開始錄音
                          setState(() {
                            isRecording = true;
                          });
                        } else {
                          onAnswer(); // 停止後立即提交答案
                          setState(() {
                            isRecording = false;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              Gaps.h16,
            ],
          ),
        );
      },
    );
  }
}

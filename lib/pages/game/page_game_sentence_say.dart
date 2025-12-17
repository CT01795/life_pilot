import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/game/controller_game_sentence_say.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/logger.dart';
import 'package:life_pilot/services/game/service_game_sentence_say.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

// ignore: must_be_immutable
class PageGameSaySentence extends StatefulWidget {
  final String gameId;
  int? gameLevel;
  PageGameSaySentence({super.key, required this.gameId, this.gameLevel});

  @override
  State<PageGameSaySentence> createState() => _PageGameSaySentenceState();
}

class _PageGameSaySentenceState extends State<PageGameSaySentence> {
  late TextEditingController textController;
  late final ControllerGameSaySentence controller;
  bool _hasPopped = false; // 旗標，避免重複 pop
  final FlutterTts flutterTts = FlutterTts(); // TTS 實例
  double size = 32.0;
  int answeredCount = 0; // 紀錄答了幾題
  late int maxQ;
  final SpeechToText speechToText = SpeechToText();
  String? userSpokenText;
  bool isRecording = false;
  int counts = 0;

  @override
  void initState() {
    super.initState();

    final auth = context.read<ControllerAuth>();
    maxQ = widget.gameLevel != null ? min(widget.gameLevel! * 2, 10) : 10;
    controller = ControllerGameSaySentence(
      gameId: widget.gameId,
      userName: auth.currentAccount ?? AuthConstants.guest,
      service: ServiceGameSaySentence(),
    );

    controller.loadNextQuestion();
    textController = TextEditingController();
  }

  // 呼叫這個方法答題並判斷是否完成題數
  void onAnswer() {
    final userAnswer = textController.text;
    counts = controller.answer(userAnswer, counts);

    if (counts == 0) {
      // 清空 spoken text
      setState(() {
        textController.clear();
        isRecording = false;
        answeredCount++;
      });
    }
    else{
      // 清空 spoken text
      setState(() {
        textController.clear();
        isRecording = false;
      });
    }

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
            title: Text("Say something (${controller.score}/100)"),
          ),
          body: Column(
            children: [
              // 第一列：喇叭按鈕
              Padding(
                padding: const EdgeInsets.all(6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.volume_up,
                          size: 60, color: Color(0xFF26A69A)),
                      onPressed: () =>
                          speak(controller.currentQuestion!.correctAnswer),
                    ),
                    Gaps.w36,
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF00897B),
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onAnswer,
                      child: Text("Check",
                          style: TextStyle(fontSize: 24, color: Colors.white)),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      controller.currentQuestion!.question,
                      style: TextStyle(
                        fontSize: 28,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Gaps.h16,
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: textController,
                        maxLines: null,
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 24, color: Colors.blueAccent),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: "Please speak",
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Gaps.h16,
              IconButton(
                icon: Icon(
                  isRecording ? Icons.mic : Icons.mic_none,
                  size: 60,
                  color: isRecording ? Colors.red : Color(0xFF26A69A),
                ),
                onPressed: () async {
                  try {
                    if (!isRecording) {
                      if (speechToText.isListening) {
                        await speechToText.stop();
                      }
                      bool available = await speechToText.initialize();
                      if (available) {
                        setState(() => isRecording = true);
                        speechToText.listen(
                          onResult: (result) {
                            setState(() {
                              textController.text = result.recognizedWords;
                              textController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                    offset: textController.text.length),
                              );
                            });
                          },
                          localeId: 'en_US', // 英文
                        );
                      }
                    } else {
                      speechToText.stop();
                      setState(() => isRecording = false);
                    }
                  } catch (e) {
                    logger.e("Speech recognition error: $e");
                  }
                },
              ),
              Gaps.h16,
            ],
          ),
        );
      },
    );
  }
}

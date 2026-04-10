// ignore_for_file: deprecated_member_use

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/game/speaking/controller_game_speaking.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';

// ignore: must_be_immutable
class PageGameSpeaking extends StatefulWidget {
  final String gameId;
  int gameLevel;
  PageGameSpeaking({super.key, required this.gameId, required this.gameLevel});

  @override
  State<PageGameSpeaking> createState() => _PageGameSpeakingState();
}

class _PageGameSpeakingState extends State<PageGameSpeaking> {
  late final ControllerGameSpeaking controller;
  bool _hasPopped = false; // 旗標，避免重複 pop
  double size = 32.0;
  int answeredCount = 0; // 紀錄答了幾題
  late int maxQ;
  bool isRecording = false;
  TextEditingController answerController =
      TextEditingController(); // 顯示答案的 TextField
  late stt.SpeechToText _speech;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    _speech.initialize(
      onStatus: (status) {
        // debug 用
        logger.d('Speech status: $status');
      },
      onError: (error) {
        logger.e('Speech error: $error');
        setState(() {
          isRecording = false;
        });
      },
    );

    final auth = context.read<ControllerAuth>();
    maxQ = widget.gameLevel == -1 ? 10 : 999;
    controller = ControllerGameSpeaking(
      gameId: widget.gameId,
      gameLevel: widget.gameLevel == -1 ? 1 : widget.gameLevel,
      userName: auth.currentAccount ?? AuthConstants.guest,
      service: ServiceGame(),
    );

    controller.loadNextQuestion();
  }

  @override
  void dispose() {
    answerController.dispose();
    super.dispose();
  }

  // 呼叫這個方法答題並判斷是否完成題數
  Future<void> onAnswer() async {
    final userAnswer = answerController.text;
    controller.answer(userAnswer);
    // 逐字顯示正確答案
    showCorrectAnswer(controller.currentQuestion!.correctAnswer);
    await Future.delayed(Duration(
        milliseconds: min(controller.repeatCounts * 1000 + 1000, 1500)));
    answerController.clear();

    if (controller.isRightAnswer == true || controller.repeatCounts == 2) {
      answeredCount++;
    }
    if (answeredCount >= maxQ && !_hasPopped) {
      _hasPopped = true;
      // 延遲一下讓 UI 更新後再跳回
      Future.microtask(() => Navigator.pop(context, true));
    }
  }

  // 逐字顯示文字
  void showCorrectAnswer(String text) async {
    //if (answerController.text.isNotEmpty) {
    //  return;
    //}
    answerController.clear();
    List<String> tmp = text.split(" ");
    for (int i = 0; i < tmp.length; i++) {
      await Future.delayed(const Duration(milliseconds: 100));

      final newValue = TextEditingValue(
        text: "${answerController.text}${tmp[i]} ",
        selection:
            TextSelection.collapsed(offset: answerController.text.length + 1),
      );
      answerController.value = newValue;
    }
  }

  void onSpeechResult(String recognizedText) {
    if (!isRecording) return;

    answerController.value = TextEditingValue(
      text: recognizedText,
      selection: TextSelection.collapsed(offset: recognizedText.length),
    );
  }

  Future<void> startSpeechRecognition({
    required void Function(String text) onResult,
  }) async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    final available = await _speech.initialize(
      onError: (error) {
        logger.e('Speech error: $error');

        // ⛔ timeout 不當作失敗
        if (error.errorMsg == 'error_speech_timeout') {
          return;
        }

        setState(() {
          isRecording = false;
        });
      },
    );

    if (!available) return;

    answerController.clear();

    await _speech.listen(
      localeId: 'en_US',
      onResult: (result) {
        if (!isRecording) return;
        onResult(result.recognizedWords);
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        partialResults: true,
      ),
      listenFor: const Duration(seconds: 10), // 🔥 最重要
      pauseFor: const Duration(seconds: 3), // 🔥 停頓多久才結束
    );
  }

  Future<void> stopSpeechRecognition() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  final player = AudioPlayer();

  Future<void> speak(String text) async {
    final containsChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
    String url = "";
    if (containsChinese) {
      url =
          "https://translate.google.com/translate_tts?ie=UTF-8&tl=zh&client=tw-ob&q=${Uri.encodeComponent(text.split('/')[0])}";
    } else {
      url =
          "https://translate.google.com/translate_tts?ie=UTF-8&tl=en&client=tw-ob&q=${Uri.encodeComponent(text.split('/')[0])}";
    }
    if (kIsWeb) {
      await player.play(UrlSource(url));
      return;
    }
    // 用 http.get 先取得 bytes，並加上 User-Agent
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
      },
    );

    if (response.statusCode == 200) {
      await player.play(BytesSource(response.bodyBytes));
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

        return AbsorbPointer(
          absorbing: controller.isBusy, // true = 全部不能點
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: Color(0xFFF5F7FA),
                appBar: AppBar(
                  backgroundColor: Color(0xFF4DB6AC),
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.pop(context, true); // 返回上一頁並通知需要刷新
                    },
                  ),
                  title: Text("Speaking (${controller.score}/100)"),
                ),
                body: Column(
                  children: [
                    // 第一列：喇叭按鈕 + 題目
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(Icons.volume_up,
                                size: 50,
                                color: isRecording
                                    ? Colors.grey
                                    : Color(0xFF26A69A)),
                            onPressed: isRecording
                                ? null // 🔒 錄音中不能按
                                : () => speak(
                                    controller.currentQuestion!.correctAnswer),
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
                              !isRecording
                                  ? Icons.mic_none
                                  : Icons.stop, // 錄音時顯示停止
                              size: 50,
                              color:
                                  !isRecording ? Color(0xFF26A69A) : Colors.red,
                            ),
                            onPressed: () async {
                              if (!isRecording) {
                                // 開始錄音
                                setState(() {
                                  isRecording = true;
                                });
                                // 🚀 開始語音辨識
                                startSpeechRecognition(
                                    onResult: onSpeechResult);
                              } else {
                                // ⏹ 停止錄音
                                stopSpeechRecognition();
                                setState(() {
                                  isRecording = false;
                                });
                                onAnswer(); // 停止後立即提交答案
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Gaps.h16,
                    // 逐字顯示答案的 TextField
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: TextField(
                          controller: answerController,
                          maxLines: null,
                          readOnly: false,
                          keyboardType: TextInputType.multiline,
                          textAlign: TextAlign.left,
                          textAlignVertical: TextAlignVertical.top,
                          style:
                              TextStyle(fontSize: 20, color: Colors.blueAccent),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: "Answer here",
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),

              // 🔹 等待遮罩（可選但很推薦）
              if (controller.isBusy)
                Container(
                  color: Colors.black.withValues(alpha: 0.2),
                ),
            ],
          ),
        );
      },
    );
  }
}

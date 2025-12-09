import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/game/controller_game_word_match.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/logger.dart';
import 'package:life_pilot/services/game/service_game_word_match.dart';
import 'package:provider/provider.dart';

// ignore: must_be_immutable
class PageGameWordMatch extends StatefulWidget {
  final String gameId;
  int? gameLevel;
  PageGameWordMatch({super.key, required this.gameId, this.gameLevel});

  @override
  State<PageGameWordMatch> createState() => _PageGameWordMatchState();
}

class _PageGameWordMatchState extends State<PageGameWordMatch> {
  late final ControllerGameWordMatch controller;
  bool _hasPopped = false; // 旗標，避免重複 pop
  final FlutterTts flutterTts = FlutterTts(); // TTS 實例
  double size = 32.0;
  int answeredCount = 0; // 紀錄答了幾題
  late int maxQ;

  @override
  void initState() {
    super.initState();

    final auth = context.read<ControllerAuth>();
    maxQ = widget.gameLevel != null ? min(widget.gameLevel! * 2, 10) : 10;
    controller = ControllerGameWordMatch(
      gameId: widget.gameId,
      userName: auth.currentAccount ?? AuthConstants.guest,
      service: ServiceGameWordMatch(),
    );
    controller.loadNextQuestion();
  }

  // 呼叫這個方法答題並判斷是否完成題數
  void onAnswer(String option) {
    controller.answer(option);
    answeredCount++;

    if (widget.gameLevel != null &&
        answeredCount >= maxQ &&
        !_hasPopped) {
      _hasPopped = true;
      // 延遲一下讓 UI 更新後再跳回
      Future.microtask(() => Navigator.pop(context, true));
    } else {
      setState(() {}); // 更新 UI
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
          // 使用 microtask 避免在 build 中立即操作 Navigator
          Future.microtask(() {
            Navigator.pop(context, true); // 回上一頁
          });

          return Scaffold(
            body: Center(
              child: Text(
                "Congratulations! Score: ${controller.score}",
              ),
            ),
          );
        }

        if (controller.isLoading || controller.currentQuestion == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final q = controller.currentQuestion!;
        return Scaffold(
          appBar: AppBar(
            title: Text("Word Matching (${controller.score}/100)"),
          ),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: Insets.all8,
                child: SizedBox(
                  width: double.infinity, // 寬度等於螢幕寬度
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFECEFF1), // blue grey 50
                      padding:
                          EdgeInsets.zero, // 🔹 移除 ElevatedButton 內建 padding
                    ),
                    onPressed: () => speak(q.question),
                    child: Row(
                      mainAxisSize: MainAxisSize.max, // 🔹 改成 max，佔滿整個按鈕
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Transform.scale(
                          scale: 4, // 放大，可自行調整
                          alignment: Alignment.centerLeft, // 左對齊
                          child: InkWell(
                            onTap: () => speak(q.question),
                            child:
                                Icon(Icons.volume_up, color: Color(0xFF212121)),
                          ),
                        ),
                        Gaps.w60,
                        Expanded(
                          child: Text(
                            q.question,
                            style: TextStyle(
                                fontSize: size, color: Color(0xFF212121)),
                            textAlign: TextAlign.start,
                            softWrap: true, // 允許換行
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Gaps.h8,
              // 三個答案按鈕
              ...q.options.map((opt) {
                Color buttonColor = Color(0xFFE3F2FD); // 淺藍
                Color borderColor = Color(0xFF1976D2); // Material Blue 700
                Icon? statusIcon; // 用於顯示勾勾或叉叉
                if (controller.lastAnswer != null) {
                  if (opt == controller.lastAnswer) {
                    statusIcon = opt == q.correctAnswer
                        ? Icon(Icons.check_rounded,
                            color: Color(0xFF2E7D32), size: size * 1.6)
                        : Icon(Icons.clear_rounded,
                            color: Color(0xFFD32F2F), size: size * 1.6);
                    buttonColor = opt == q.correctAnswer
                        ? Color(0xFFC8E6C9) // 淺綠
                        : Color(0xFFFFCDD2); // 淺紅
                    borderColor = opt == q.correctAnswer
                        ? Color(0xFF388E3C) //Material Green 700
                        : Color(0xFFD32F2F); //Material Red 700
                  } else if (opt == q.correctAnswer &&
                      controller.showCorrectAnswer) {
                    statusIcon = Icon(Icons.check_rounded,
                        color: Color(0xFF2E7D32), size: size * 1.6);
                    buttonColor = Color(0xFFC8E6C9); // 淺綠
                    borderColor = Color(0xFF388E3C); //Material Green 700
                  }
                }
                return Padding(
                  padding: Insets.all8,
                  child: SizedBox(
                    width: double.infinity, // 寬度等於螢幕寬度
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                      ),
                      onPressed: () => speak(
                          opt), // 🔹 原本按鈕改成 TTS //=> controller.answer(opt),
                      child: Row(
                        mainAxisSize: MainAxisSize.max, // 🔹 改成 max，佔滿整個按鈕
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // ⭐ 改成自訂 CheckBox 風格的 Radio
                          GestureDetector(
                            onTap: () => onAnswer(opt),
                            /*() {
                              controller.answer(opt);
                              setState(() {});
                            },*/
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.rectangle,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: borderColor,
                                ),
                              ),
                              child: Center(
                                child: opt == controller.lastAnswer
                                    ? Icon(Icons.check,
                                        color: borderColor, size: 48)
                                    : SizedBox.shrink(),
                              ),
                            ),
                          ),
                          Gaps.w24,
                          Expanded(
                            child: Text(
                              opt,
                              style: TextStyle(
                                  fontSize: size, color: Color(0xFF212121)),
                              softWrap: true, // 允許自動換行
                              textAlign: TextAlign.start,
                            ),
                          ),
                          Gaps.w8,
                          // ⭐ 這裡必須安全顯示
                          statusIcon ?? SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

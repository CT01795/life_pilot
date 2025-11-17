import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/game/controller_game_word_match.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/logger.dart';
import 'package:life_pilot/services/game/service_game_word_match.dart';
import 'package:provider/provider.dart';

class PageGameWordMatch extends StatefulWidget {
  final String gameId;
  const PageGameWordMatch({super.key, required this.gameId});

  @override
  State<PageGameWordMatch> createState() => _PageGameWordMatchState();
}

class _PageGameWordMatchState extends State<PageGameWordMatch> {
  late final ControllerGameWordMatch controller;
  bool _hasPopped = false; // 旗標，避免重複 pop
  final FlutterTts flutterTts = FlutterTts(); // TTS 實例
  double size = 32.0;

  @override
  void initState() {
    super.initState();

    final auth = context.read<ControllerAuth>();

    controller = ControllerGameWordMatch(
      gameId: widget.gameId,
      userName: auth.currentAccount ?? AuthConstants.guest,
      service: ServiceGameWordMatch(),
    );
    controller.loadNextQuestion();
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
      await flutterTts.setSpeechRate(0.7); // 🟢 英文語速
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
              Gaps.h16,
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, // 讓文字多行時對齊喇叭上方
                children: [
                  InkWell(
                    onTap: () => speak(q.question),
                    child: Icon(Icons.volume_up, size: size * 3),
                  ),
                  Gaps.w8,
                  // 這裡要用 Flexible 才能換行！！
                  Flexible(
                    child: InkWell(
                      onTap: () => speak(q.question),
                      child: Text(
                        q.question,
                        style: TextStyle(fontSize: size),
                        textAlign: TextAlign.start,
                        softWrap: true, // 允許換行
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ),
                ],
              ),
              Gaps.h8,
              // 三個答案按鈕
              ...q.options.map((opt) {
                Color buttonColor = Colors.blue;
                String icon = constEmpty; // 用於顯示勾勾或叉叉
                // 如果已選答案
                if (controller.lastAnswer != null) {
                  if (opt == controller.lastAnswer) {
                    // 使用者選的答案
                    buttonColor = opt == q.correctAnswer
                        ? Colors.green
                        : Colors.redAccent.shade100;
                    icon = opt == q.correctAnswer ? '✅' : '❌';
                  } else if (opt == q.correctAnswer &&
                      controller.showCorrectAnswer) {
                    // 顯示正確答案
                    buttonColor = Colors.green;
                    icon = '✅';
                  }
                }

                return Padding(
                  padding: Insets.all8,
                  child: SizedBox(
                    width: double.infinity, // 寬度等於螢幕寬度
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        padding: EdgeInsets.zero, // 🔹 移除 ElevatedButton 內建 padding
                      ),
                      onPressed: () => speak(
                          opt), // 🔹 原本按鈕改成 TTS //=> controller.answer(opt),
                      child: Row(
                        mainAxisSize: MainAxisSize.max, // 🔹 改成 max，佔滿整個按鈕
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Transform.scale(
                            scale: 3.2, // 放大，可自行調整
                            alignment: Alignment.centerLeft, // 左對齊
                            child: Radio<String>(
                              value: opt, // 這個按鈕的值
                              // ignore: deprecated_member_use
                              groupValue: controller.lastAnswer, // 當前選中的值
                              fillColor: WidgetStateProperty.resolveWith((states) {
                                return Colors.white; // 選中時白色
                              }),
                              // ignore: deprecated_member_use
                              onChanged: (val) {
                                if (val != null) {
                                  controller.answer(val); // 更新答案
                                  setState(() {}); // 重新刷新 UI
                                }
                              },
                            ),
                          ),
                          Gaps.w60,
                          Expanded(
                            child: Text(
                              opt,
                              style: TextStyle(fontSize: size),
                              softWrap: true, // 允許自動換行
                              textAlign: TextAlign.start,
                            ),
                          ),
                          Gaps.w8,
                          if (icon.isNotEmpty)
                            Text(
                              icon,
                              style: TextStyle(fontSize: size),
                            ),
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

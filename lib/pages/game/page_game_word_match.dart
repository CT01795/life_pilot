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
      await flutterTts.stop();
    } catch (e, st) {
      logger.e(e.toString() + st.toString());
    }
    final containsChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
    if (containsChinese) {
      await flutterTts.setLanguage("zh-TW");
      await flutterTts.setSpeechRate(0.2); // 🟢 中文語速（超重要）
      await flutterTts.setVolume(1.0); // 中文預設會比較小聲 → 拉滿
      await flutterTts.speak(text);
    } else {
      await flutterTts.setLanguage("en-US");
      await flutterTts.setSpeechRate(0.6); // 🟢 英文語速
      await flutterTts.setVolume(1.0);
      await flutterTts.speak(text);
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
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, // 讓文字多行時對齊喇叭上方
                  children: [
                    InkWell(
                      onTap: () => speak(q.question),
                      child: Icon(Icons.volume_up, size: size * 1.5),
                    ),
                    Gaps.w8,
                    // 這裡要用 Flexible 才能換行！！
                    Flexible(
                      child: Text(
                        q.question,
                        style: TextStyle(fontSize: size),
                        textAlign: TextAlign.center,
                        softWrap: true,     // 允許換行
                        overflow: TextOverflow.visible,
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
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 12), // 按鈕自適應高度
                        ),
                        onPressed: () => controller.answer(opt),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkWell(
                              onTap: () => speak(opt),
                              child: Icon(Icons.volume_up, size: size * 1.5),
                            ),
                            Gaps.w8,
                            Flexible(
                              child: Text(
                                opt,
                                style: TextStyle(fontSize: size),
                                softWrap: true, // 允許自動換行
                                textAlign: TextAlign.center,
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
          ),
        );
      },
    );
  }
}

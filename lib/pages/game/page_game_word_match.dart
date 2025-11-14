import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/game/controller_game_word_match.dart';
import 'package:life_pilot/core/const.dart';
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
            title: Text("Word Matching (${controller.score}/10)"),
          ),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  q.question,
                  style: const TextStyle(fontSize: 32),
                  textAlign: TextAlign.center, // 文字水平置中
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
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), // 按鈕自適應高度
                      ),
                      onPressed: () => controller.answer(opt),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              opt,
                              style: const TextStyle(fontSize: 32),
                              softWrap: true, // 允許自動換行
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (icon.isNotEmpty) ...[
                            Gaps.w8,
                            Text(
                              icon,
                              style: const TextStyle(fontSize: 32),
                            ),
                          ],
                        ],
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

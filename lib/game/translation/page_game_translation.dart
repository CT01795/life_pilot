import 'dart:math';

import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/game/translation/controller_game_translation.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:provider/provider.dart';

// ignore: must_be_immutable
class PageGameTranslation extends StatefulWidget {
  final String gameId;
  int? gameLevel;
  PageGameTranslation({super.key, required this.gameId, this.gameLevel});

  @override
  State<PageGameTranslation> createState() => _PageGameTranslationState();
}

class _PageGameTranslationState extends State<PageGameTranslation> {
  late final ControllerGameTranslation controller;
  bool _hasPopped = false; // 旗標，避免重複 pop
  double size = 32.0;

  @override
  void initState() {
    super.initState();

    final auth = context.read<ControllerAuth>();
    controller = ControllerGameTranslation(
      gameId: widget.gameId,
      userName: auth.currentAccount ?? AuthConstants.guest,
      service: ServiceGame(),
      maxQuestions: widget.gameLevel != null ? min(widget.gameLevel!, 10) : 999,
    );
    controller.loadNextQuestion();
  }

  // 呼叫這個方法答題並判斷是否完成題數
  void onAnswer(String option) {
    controller.answer(option);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // ✅ 判斷遊戲是否完成
        if (controller.isFinished && !_hasPopped) {
          _hasPopped = true;
          Future.microtask(() => Navigator.pop(context, true));
          return const SizedBox.shrink(); // 回上一頁前先返回空 widget
        }

        if (controller.isLoading || controller.currentQuestion == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final q = controller.currentQuestion!;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context, true); // 返回上一頁並通知需要刷新
              },
            ),
            title: Text("Translation (${controller.score}/100)"),
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
                    onPressed: () => controller.speak(q.question),
                    child: Row(
                      mainAxisSize: MainAxisSize.max, // 🔹 改成 max，佔滿整個按鈕
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Transform.scale(
                          scale: 4, // 放大，可自行調整
                          alignment: Alignment.centerLeft, // 左對齊
                          child: InkWell(
                            onTap: () => controller.speak(q.question),
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
                Color buttonColor = controller.getButtonColor(opt); // 淺藍
                Color borderColor =
                    controller.getBorderColor(opt); // Material Blue 700
                Icon? statusIcon = controller.getStatusIcon(opt); // 用於顯示勾勾或叉叉
                return Padding(
                  padding: Insets.all8,
                  child: SizedBox(
                    width: double.infinity, // 寬度等於螢幕寬度
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                      ),
                      onPressed: () => controller.speak(
                          opt), // 🔹 原本按鈕改成 TTS //=> controller.answer(opt),
                      child: Row(
                        mainAxisSize: MainAxisSize.max, // 🔹 改成 max，佔滿整個按鈕
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // ⭐ 改成自訂 CheckBox 風格的 Radio
                          GestureDetector(
                            onTap: () => onAnswer(opt),
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

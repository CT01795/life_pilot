import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/game/controller_game_grammar.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/game/model_game_grammar.dart';
import 'package:life_pilot/services/game/service_game.dart';
import 'package:provider/provider.dart';

// ignore: must_be_immutable
class PageGameGrammar extends StatefulWidget {
  final String gameId;
  int? gameLevel;
  PageGameGrammar({super.key, required this.gameId, this.gameLevel});

  @override
  State<PageGameGrammar> createState() => _PageGameGrammarState();
}

class _PageGameGrammarState extends State<PageGameGrammar> {
  late final ControllerGameGrammar controller;
  late final FlutterTts flutterTts; // TTS 實例
  late int maxQ;
  late int playerMaxHp;
  late int monsterMaxHp;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();
    flutterTts.setVolume(1.0);
    flutterTts.setSpeechRate(0.6); // 預設語速
    flutterTts.setLanguage("en-US");

    final auth = context.read<ControllerAuth>();
    maxQ = widget.gameLevel != null ? min(widget.gameLevel!, 10) : 1000;
    controller = ControllerGameGrammar(
      gameId: widget.gameId,
      userName: auth.currentAccount ?? AuthConstants.guest,
      service: ServiceGame(),
      model: ModelGameGrammar()
    );
    
    controller.startBattle(widget.gameLevel?? 1);
    playerMaxHp = controller.model.player.hp;
    monsterMaxHp = controller.model.monster!.hp;
  }

  // 呼叫這個方法答題並判斷是否完成題數
  void onAnswer(String userAnswer) {
    controller.answer(userAnswer);

    if (widget.gameLevel != null && controller.answeredCount >= maxQ) {
      // 延遲一下讓 UI 更新後再跳回
      Future.microtask(() => Navigator.pop(context, true));
    }
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    //final containsChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
    //await flutterTts.setLanguage(containsChinese ? "zh-TW" : "en-US");
    //await flutterTts.setSpeechRate(containsChinese ? 0.4 : 0.6); // 🟢 語速
    await flutterTts.speak(text.split('/')[0]);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isFinished && !_popped) {
          _popped = true;
          Future.microtask(() => Navigator.pop(context, true));
          return Center(
            child: Text("Congratulations! Score: ${controller.model.player.hp}"),
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
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context, true); // 返回上一頁並通知需要刷新
              },
            ),
            title: Text("English RPG Adventure (${controller.model.player.hp})"),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // 🧑 玩家血條（左側）
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.favorite, color: Colors.red),
                              Gaps.w8,
                              Text(
                                '${controller.model.player.hp}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Gaps.h4,
                          hpBar(
                            current: controller.model.player.hp,
                            max: playerMaxHp,
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ),
                    Gaps.w24, // 左右間距
                    // 👾 怪物血條（右側）
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                '${controller.model.monster!.hp}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Gaps.w8,
                              Icon(Icons.android, color: Color(0xFF7E57C2)),
                            ],
                          ),
                          Gaps.h4,
                          hpBar(
                            current: controller.model.monster!.hp,
                            max: monsterMaxHp,
                            color: Color(0xFF7E57C2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Gaps.h8,
              // 第一列：喇叭按鈕
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center, // 🔥 整組置中
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.volume_up,
                            size: 44,
                            color: Color(0xFF26A69A),
                          ),
                          onPressed: () =>
                              speak(controller.currentQuestion!.question.replaceAll("______", controller.currentQuestion!.correctAnswer).replaceAll("<-->", ",")),
                        ),
                        Gaps.w8, // 🔥 小間距就好
                        Flexible(
                          child: Text(
                            controller.currentQuestion!.question,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF263238),
                            ),
                            textAlign: TextAlign.center,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (controller.isRightAnswer != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: controller.isRightAnswer == true
                          ? Color(0xFF81C784)
                          : Color(0xFFE57373),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          controller.isRightAnswer == true
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: Colors.white,
                          size: 32,
                        ),
                        Gaps.w8,
                        Flexible(
                          child: Text(
                            controller.currentQuestion!.correctAnswer,
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Gaps.h8,
              // 第二列：答案填答區
              ...controller.model.currentQuestion!.options.map(
                (opt) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF64B5F6),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => onAnswer(opt),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget hpBar({
  required int current,
  required int max,
  required Color color,
}) {
  final percent = (current / max).clamp(0.0, 1.0);

  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: LinearProgressIndicator(
      value: percent,
      minHeight: 10,
      backgroundColor: color.withValues(alpha: 0.2),
      valueColor: AlwaysStoppedAnimation(color),
    ),
  );
}

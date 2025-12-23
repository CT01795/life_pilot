import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/game/controller_game_sentence.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/logger.dart';
import 'package:life_pilot/models/game/model_game_sentence.dart';
import 'package:life_pilot/services/game/service_game.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

// ignore: must_be_immutable
class PageGameSentence extends StatefulWidget {
  final String gameId;
  int? gameLevel;
  PageGameSentence({super.key, required this.gameId, this.gameLevel});

  @override
  State<PageGameSentence> createState() => _PageGameSentenceState();
}

class _PageGameSentenceState extends State<PageGameSentence> {
  late final ControllerGameSentence controller;
  List<WordItem> options = []; // 底部文字方塊
  List<WordItem?> answerSlots = []; // 上方拖曳區
  bool _hasPopped = false; // 旗標，避免重複 pop
  final FlutterTts flutterTts = FlutterTts(); // TTS 實例
  double size = 32.0;
  int answeredCount = 0; // 紀錄答了幾題
  late int maxQ;
  bool? isRightAnswer; // 答案對錯

  @override
  void initState() {
    super.initState();

    final auth = context.read<ControllerAuth>();
    maxQ = widget.gameLevel != null ? min(widget.gameLevel!, 10) : 10;
    controller = ControllerGameSentence(
      gameId: widget.gameId,
      userName: auth.currentAccount ?? AuthConstants.guest,
      service: ServiceGame(),
    );

    // 🔥 當題目載入時，更新 currentOrder 並打亂
    controller.addListener(() {
      if (controller.currentQuestion != null) {
        setState(() {
          options = List.generate(
              controller.currentQuestion!.options.length,
              (i) => WordItem(
                  id: Uuid().v4(),
                  text: controller.currentQuestion!.options[i]))
            ..shuffle();
          answerSlots =
              List.filled(controller.currentQuestion!.options.length, null);
          // 🔹 每題開始時，重置答案顯示
          isRightAnswer = null;
        });
      }
    });
    controller.loadNextQuestion();
  }

  // 呼叫這個方法答題並判斷是否完成題數
  void onAnswer() {
    // 將 answerSlots 轉成文字陣列，忽略 null
    final userAnswer = controller.currentQuestion?.type == "word"
        ? answerSlots.map((e) => e?.text ?? constEmpty).join(constEmpty)
        : answerSlots.map((e) => e?.text ?? constEmpty).join(' ');
    controller.answer(userAnswer);
    answeredCount++;
    isRightAnswer = userAnswer == controller.currentQuestion!.correctAnswer;

    if (widget.gameLevel != null && answeredCount >= maxQ && !_hasPopped) {
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
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context, true); // 返回上一頁並通知需要刷新
              },
            ),
            title: Text("Word and sentence builder (${controller.score}/100)"),
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
                      icon: Icon(Icons.volume_up, size: 60, color: Color(0xFF26A69A)),
                      onPressed: () =>
                          speak(controller.currentQuestion!.correctAnswer),
                    ),
                    Gaps.w36,
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF00897B),
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onAnswer,
                      child: Text("Check", style: TextStyle(fontSize: 24, color: Colors.white)),
                    ),
                  ],
                ),
              ),
              if (isRightAnswer != null)
                Container(
                  padding: EdgeInsets.all(8),
                  width: double.infinity,                      // 允許換行最重要
                  decoration: BoxDecoration(
                    color: isRightAnswer == true ? Color(0xFF81C784) : Color(0xFFE57373),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,       // ⬅ 水平置中
                    crossAxisAlignment: CrossAxisAlignment.center,     // ⬅ 垂直置中
                    children: [
                      Icon(
                        isRightAnswer == true ? Icons.check_circle : Icons.close,
                        color: Colors.white,
                        size: 36,
                      ),
                      Gaps.w8,
                      /// 不用 Expanded → 用 Flexible 才不會把 icon 推開
                      Flexible(
                        child: Text(
                          controller.currentQuestion!.correctAnswer,
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,  // 文字置中
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                ),
              Gaps.h16,
              // 第二列：答案填答區
              LayoutBuilder(
                builder: (context, constraints) {
                  // 計算每個字塊寬度，最大不超過父容器寬度
                  final minHeight = 80.0;
                  return Container(
                    padding: EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      spacing: 4, // 水平間距
                      runSpacing: 4, // 垂直間距
                      alignment: WrapAlignment.center,
                      children: List.generate(answerSlots.length, (index) {
                        final word = answerSlots[index];
                        final fontSize = 28.0;
                        final width = word == null
                            ? 80.0
                            : max(80.0, word.text.length * 40.0);

                        return DragTarget<WordItem>(
                          onWillAcceptWithDetails: (_) => true,
                          onAcceptWithDetails: (detail) {
                            final dragged = detail.data;
                            setState(() {
                              final indexInUpper = answerSlots
                                  .indexWhere((e) => e?.id == dragged.id);

                              if (indexInUpper != -1) {
                                // 上方 → 上方交換
                                final temp = answerSlots[index];
                                answerSlots[index] = dragged;
                                answerSlots[indexInUpper] = temp;
                              } else {
                                // 下方 → 上方
                                if (answerSlots[index] != null) {
                                  options.add(answerSlots[index]!);
                                }
                                answerSlots[index] = dragged;
                                options.removeWhere((e) => e.id == dragged.id);
                              }
                            });
                          },
                          builder: (context, candidateData, rejectedData) {
                            return AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              width: width,
                              padding: EdgeInsets.symmetric(
                                  vertical: 3, horizontal: 6),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: word == null
                                    ? Colors.grey[300]
                                    : Color(0xFFB2DFDB),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: word == null
                                  ? SizedBox(height: minHeight)
                                  : Draggable<WordItem>(
                                      data: word,
                                      feedback: Material(
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 3, horizontal: 6),
                                          color: Color(0xFFB2DFDB),
                                          child: Text(word.text,
                                              style: TextStyle(
                                                  fontSize: fontSize)),
                                        ),
                                      ),
                                      childWhenDragging: Container(
                                        width: width,
                                        height: minHeight,
                                        color: Color(0xFF80CBC4),
                                      ),
                                      child: Text(
                                        word.text,
                                        style: TextStyle(fontSize: fontSize),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                            );
                          },
                        );
                      }),
                    ),
                  );
                },
              ),
              Gaps.h16,
              // 第三列：待用區（整個區域作 DragTarget）
              Expanded(
                child: DragTarget<WordItem>(
                  onWillAcceptWithDetails: (detail) =>
                      answerSlots.contains(detail.data),
                  onAcceptWithDetails: (detail) {
                    final dragged = detail.data;
                    setState(() {
                      final indexInUpper =
                          answerSlots.indexWhere((e) => e?.id == dragged.id);
                      if (indexInUpper != -1) {
                        answerSlots[indexInUpper] = null;
                        options.add(dragged);
                      }
                    });
                  },
                  builder: (context, candidateData, rejectedData) {
                    return Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.center, // Row 水平置中
                        mainAxisAlignment: MainAxisAlignment.start, // 垂直靠上
                        children: [
                          Wrap(
                            spacing: 8, // 水平間距
                            runSpacing: 8, // 垂直間距
                            alignment: WrapAlignment.center,
                            children: options.map((word) {
                              return Draggable<WordItem>(
                                data: word,
                                feedback: Material(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        vertical: 3, horizontal: 6),
                                    color: Color(0xFFB2DFDB),
                                    child: Text(word.text,
                                        style: TextStyle(fontSize: 24)),
                                  ),
                                ),
                                childWhenDragging: Container(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 3, horizontal: 6),
                                  margin: EdgeInsets.symmetric(horizontal: 4),
                                  color: Color(0xFF80CBC4),
                                  child: Text(word.text,
                                      style: TextStyle(fontSize: 24)),
                                ),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 3, horizontal: 6),
                                  margin: EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFB2DFDB),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(word.text,
                                      style: TextStyle(fontSize: 24)),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

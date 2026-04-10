// ignore_for_file: deprecated_member_use

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/game/sentence/controller_game_sentence.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/game/sentence/model_game_sentence.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:html' as html;

// ignore: must_be_immutable
class PageGameSentence extends StatefulWidget {
  final String gameId;
  int gameLevel;
  PageGameSentence({super.key, required this.gameId, required this.gameLevel});

  @override
  State<PageGameSentence> createState() => _PageGameSentenceState();
}

class _PageGameSentenceState extends State<PageGameSentence> {
  late final ControllerGameSentence controller;
  bool _hasPopped = false; // 旗標，避免重複 pop
  double size = 32.0;
  int answeredCount = 0; // 紀錄答了幾題
  late int maxQ;

  @override
  void initState() {
    super.initState();

    final auth = context.read<ControllerAuth>();
    maxQ = widget.gameLevel == -1 ? 10 : 999;
    controller = ControllerGameSentence(
      gameId: widget.gameId,
      gameLevel: widget.gameLevel == -1 ? 1 : widget.gameLevel,
      userName: auth.currentAccount ?? AuthConstants.guest,
      service: ServiceGame(),
    );
    controller.loadNextQuestion();
  }

  // 呼叫這個方法答題並判斷是否完成題數
  void onAnswer() {
    controller.checkAnswer();
    answeredCount++;

    if (answeredCount >= maxQ && !_hasPopped) {
      _hasPopped = true;
      // 延遲一下讓 UI 更新後再跳回
      Future.microtask(() => Navigator.pop(context, true));
    }
  }

  final player = AudioPlayer();

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    
    final containsChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
    if (kIsWeb) {
      final utterance = html.SpeechSynthesisUtterance(text);
      utterance.lang =
          containsChinese ? 'zh-TW' : 'en-US';

      html.window.speechSynthesis?.speak(utterance);
      return;
    }
    String url = "";
    if (containsChinese) {
      url =
          "https://translate.google.com/translate_tts?ie=UTF-8&tl=zh&client=tw-ob&q=${Uri.encodeComponent(text.split('/')[0])}";
    } else {
      url =
          "https://translate.google.com/translate_tts?ie=UTF-8&tl=en&client=tw-ob&q=${Uri.encodeComponent(text.split('/')[0])}";
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
        title: AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            return Text(
              "Word and sentence builder (${controller.score}/100)",
            );
          },
        ),
      ),
      body: AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            if (controller.isFinished && !_hasPopped) {
              _hasPopped = true;
              Future.microtask(() => Navigator.pop(context, true));
              return const SizedBox.shrink();
            }

            if (controller.isLoading || controller.currentQuestion == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
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
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: onAnswer,
                        child: Text("Check",
                            style:
                                TextStyle(fontSize: 24, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                if (controller.isRightAnswer != null)
                  Container(
                    padding: EdgeInsets.all(8),
                    width: double.infinity, // 允許換行最重要
                    decoration: BoxDecoration(
                      color: controller.isRightAnswer == true
                          ? Color(0xFF81C784)
                          : Color(0xFFE57373),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center, // ⬅ 水平置中
                      crossAxisAlignment: CrossAxisAlignment.center, // ⬅ 垂直置中
                      children: [
                        Icon(
                          controller.isRightAnswer == true
                              ? Icons.check_circle
                              : Icons.close,
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
                            textAlign: TextAlign.center, // 文字置中
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
                        children: List.generate(controller.answerSlots.length,
                            (index) {
                          final word = controller.answerSlots[index];
                          final fontSize = 28.0;
                          final width = word == null
                              ? 80.0
                              : max(80.0, word.text.length * 40.0);

                          return DragTarget<WordItem>(
                            onWillAcceptWithDetails: (_) => true,
                            onAcceptWithDetails: (detail) {
                              controller.moveWordToSlot(index, detail.data);
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
                        controller.answerSlots.contains(detail.data),
                    onAcceptWithDetails: (detail) {
                      final dragged = detail.data;
                      final indexInUpper = controller.answerSlots
                          .indexWhere((e) => e?.id == dragged.id);
                      if (indexInUpper != -1) {
                        controller.removeWordFromSlot(indexInUpper);
                      }
                    },
                    builder: (context, candidateData, rejectedData) {
                      return Container(
                        width: double.infinity,
                        padding:
                            EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(16)),
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
                              children: controller.options.map((word) {
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
            );
          }),
    );
  }
}

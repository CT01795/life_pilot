import 'dart:math';

import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/game/word_search/controller_game_word_search.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/game/word_search/model_game_word_search.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:provider/provider.dart';

// ignore: must_be_immutable
class PageGameWordSearch extends StatefulWidget {
  final String gameId;
  int? gameLevel;
  PageGameWordSearch({super.key, required this.gameId, this.gameLevel});

  @override
  State<PageGameWordSearch> createState() => _PageGameWordSearchState();
}

class _PageGameWordSearchState extends State<PageGameWordSearch> {
  late final ControllerGameWordSearch controller;
  bool _hasPopped = false; // 旗標，避免重複 pop
  double size = 20.0;

  @override
  void initState() {
    super.initState();

    final auth = context.read<ControllerAuth>();
    controller = ControllerGameWordSearch(
      gameId: widget.gameId,
      userName: auth.currentAccount ?? AuthConstants.guest,
      service: ServiceGame(),
      maxQuestions: widget.gameLevel != null ? min(widget.gameLevel!, 10) : 999,
      board: WordSearchBoard(12), // ⭐ 12x12 Grid
      currentQuestion: ModelGameWordSearch(
        questionId: '',
        question: '',
      ),
    );
    controller.loadNextQuestion();
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

        if (controller.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context, true); // 返回上一頁並通知需要刷新
              },
            ),
            title: Text("Word Search (${controller.score}/100)"),
          ),
          body: Column(
            children: [
              // ⭐ 題目顯示
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: 'Find  ',
                        style: const TextStyle(color: Colors.black), // 黑色
                      ),
                      TextSpan(
                        text: controller.currentQuestion.question,
                        style: const TextStyle(color: Colors.blue,fontSize:50), // 藍色
                      ),
                    ],
                  ),
                ),
              ),
              // ⭐ 提交按鈕（保險）
              Padding(
                padding: Insets.all8,
                child: ElevatedButton(
                  onPressed: controller.board.currentSelection.isEmpty
                      ? null
                      : controller.submitSelection,
                  child: const Text('Submit'),
                ),
              ),
              // ⭐ Word Search Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AspectRatio(
                    aspectRatio: 1, // 正方形
                    child: _WordSearchGrid(controller),
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

class _WordSearchGrid extends StatelessWidget {
  final ControllerGameWordSearch controller;

  const _WordSearchGrid(this.controller);

  @override
  Widget build(BuildContext context) {
    final board = controller.board;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 取可用寬高，選最小值作為正方形邊長
        final gridSize = board.size;
        final cellSize = constraints.maxWidth / gridSize; // 只用寬度
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridSize,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 1, // 保持正方形
          ),
          itemCount: gridSize * gridSize,
          itemBuilder: (context, index) {
            final row = index ~/ gridSize;
            final col = index % gridSize;
            final cell = board.grid[row][col];

            return GestureDetector(
              onTapDown: (_) => controller.onSelectCell(cell),
              child: Container(
                width: cellSize,
                height: cellSize,
                decoration: BoxDecoration(
                  color: cell.correct
                      ? Colors.green
                      : cell.selected
                          ? Colors.blue
                          : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      cell.letter.toLowerCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: cellSize * 0.6, // 字體大小約為格子大小 60%
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
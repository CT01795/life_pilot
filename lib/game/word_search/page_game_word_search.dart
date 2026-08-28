import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/game/word_search/controller_game_word_search.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/game/word_search/model_game_word_search.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:provider/provider.dart';

// ignore: must_be_immutable
class PageGameWordSearch extends StatefulWidget {
  final String gameId;
  int gameLevel;
  final String questionBank;
  PageGameWordSearch(
      {super.key,
      required this.gameId,
      required this.gameLevel,
      this.questionBank = 'admin'});

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
      gameLevel: widget.gameLevel == -1 ? 1 : widget.gameLevel,
      questionBank: widget.questionBank,
      userName: auth.currentAccount ?? AuthConstants.guest,
      service: ServiceGame(),
      maxQuestions: widget.gameLevel == -1 ? 10 : 999,
      board: WordSearchBoard(12), // ⭐ 12x12 Grid
      currentQuestion: ModelGameWordSearch(
        questionId: '',
        question: '',
      ),
    );
    controller.loadNextQuestion();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final loc = AppLocalizations.of(context)!;
        final isCompact = MediaQuery.sizeOf(context).width < 600;
        // ✅ 判斷遊戲是否完成
        if (controller.isFinished && !_hasPopped) {
          _hasPopped = true;
          Future.microtask(() {
            if (mounted) Navigator.pop(context, true);
          });
          return const SizedBox.shrink(); // 回上一頁前先返回空 widget
        }

        if (controller.loadError != null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loc.unknownError),
                  Gaps.h8,
                  ElevatedButton(
                    onPressed: controller.retry,
                    child: Text(loc.retry),
                  ),
                ],
              ),
            ),
          );
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
                Navigator.maybePop(context);
              },
            ),
            title: Text("Word Search (${controller.score}/100)"),
          ),
          body: Column(
            children: [
              // ⭐ 題目顯示
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
                    onPressed: () =>
                        controller.speak(controller.currentQuestion.question),
                    child: Row(
                      mainAxisSize: MainAxisSize.max, // 🔹 改成 max，佔滿整個按鈕
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        IconButton(
                          tooltip: loc.speakingText,
                          onPressed: () => controller
                              .speak(controller.currentQuestion.question),
                          icon: const Icon(
                            Icons.volume_up,
                            color: Color(0xFF212121),
                          ),
                          iconSize: isCompact ? 30 : 36,
                        ),
                        Gaps.w8,
                        Expanded(
                          child: Text(
                            controller.currentQuestion.question,
                            style: TextStyle(
                              fontSize: isCompact ? 26 : 36,
                              color: const Color(0xFF212121),
                            ),
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
              // ⭐ 提交按鈕（保險）
              Padding(
                padding: Insets.all8,
                child: ElevatedButton(
                  onPressed: controller.board.currentSelection.isEmpty
                      ? null
                      : controller.submitSelection,
                  child: const Text('Submit',
                      style: TextStyle(fontSize: 24, color: Colors.white)),
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

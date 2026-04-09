import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/game/puzzle_map/controller_game_puzzle_map.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/game/puzzle_map/model_game_puzzle_map.dart';
import 'package:life_pilot/game/grammar/page_game_grammar.dart';
import 'package:life_pilot/game/sentence/page_game_sentence.dart';
import 'package:life_pilot/game/speaking/page_game_speaking.dart';
import 'package:life_pilot/game/translation/page_game_translation.dart';
import 'package:life_pilot/game/word_search/page_game_word_search.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:provider/provider.dart';

class PageGamePuzzleMap extends StatefulWidget {
  final String gameId;
  final int gameLevel;
  const PageGamePuzzleMap(
      {super.key, required this.gameId, required this.gameLevel});

  @override
  State<PageGamePuzzleMap> createState() => _PageGamePuzzleMapState();
}

class _PageGamePuzzleMapState extends State<PageGamePuzzleMap> {
  bool showHint = false;
  late ModelGamePuzzleMap map;
  late int gameSize;
  ui.Image? puzzleImage;
  ControllerGamePuzzleMap? controller;

  @override
  void initState() {
    super.initState();
    gameSize = 4;
    final auth = context.read<ControllerAuth>();
    controller = ControllerGamePuzzleMap(
      userName: auth.currentAccount ?? AuthConstants.guest,
      service: ServiceGame(),
      gameId: widget.gameId,
      gameLevel: widget.gameLevel,
    );
    final maps = [
      "assets/maps/taiwan.png", //台灣
      "assets/maps/taiwan_outlying_islands.png", //台灣與離島
      "assets/maps/penghu.png", //澎湖
      "assets/maps/kinmen.png", //金門
      "assets/maps/lienchiang.png", //5 馬祖
      "assets/maps/greenland.png", //綠島
      "assets/maps/little_ryukyu.png", //小琉球
      "assets/maps/lanyu.png", //蘭嶼
      "assets/maps/taiwan_outlying_islands.png", //台灣與離島
      "assets/maps/world.png", //10
      "assets/maps/east_asia.png", //東亞
      "assets/maps/korea.png", //韓國
      "assets/maps/japan.png", //日本
      "assets/maps/kansai.png", //關西
      "assets/maps/okinawa.png", //15 沖繩
      "assets/maps/china.png", //中國大陸
      "assets/maps/east_asia.png", //東亞
      "assets/maps/world.png", //世界地圖
      "assets/maps/southeast_asia.png", //東南亞
      "assets/maps/vietnam.png", //20 越南
      "assets/maps/thailand.png", //泰國
      "assets/maps/malaysia.png", //馬來西亞
      "assets/maps/singapore.png", //新加坡
      "assets/maps/philippines.png", //菲律賓
      "assets/maps/southeast_asia.png", //25 東南亞
      "assets/maps/south_asia.png", //南亞
      "assets/mapscenter_asia.png", //中亞
      "assets/maps/asia.png", //亞洲
      "assets/maps/world.png", //世界地圖
      "assets/maps/oceania.png", //30 大洋洲
      "assets/maps/australia.png", //澳大利亞
      "assets/maps/new_zealand.png", //紐西蘭
      "assets/maps/oceania.png", //大洋洲
      "assets/maps/world.png", //世界地圖
      "assets/maps/north_america.png", //35 北美洲
      "assets/maps/jianada.png", //加拿大
      "assets/maps/america.png", //美國
      "assets/maps/north_america.png", //北美洲
      "assets/maps/arctic.png", //北極
      "assets/maps/antarctica.png", //40 南極
      "assets/maps/world.png" //世界地圖
          "assets/maps/central_america.png", //中美洲
      "assets/maps/south_america.png", //南美洲
      "assets/maps/europe.png", //歐洲
      "assets/maps/france.png", //45 法國
      "assets/maps/africa.png", //非洲
      "assets/maps/world.png" //47 世界地圖
    ];
    map = ModelGamePuzzleMap(assetPath: maps[widget.gameLevel - 1]);
    _loadImage(map.assetPath).then((img) {
      controller!.setGridSize(img.width, img.height, gameSize);
      setState(() {
        puzzleImage = img;
      });
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<ui.Image> _loadImage(String path) async {
    final data = await DefaultAssetBundle.of(context).load(path);
    final list = Uint8List.view(data.buffer);
    final codec = await ui.instantiateImageCodec(list);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || puzzleImage == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final ctrl = controller!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, true); // 返回上一頁並通知需要刷新
          },
        ),
        title: const Text("Puzzle map"),
        actions: [
          IconButton(
            icon: Icon(
              Icons.lightbulb_outline,
              color: Colors.white,
            ),
            tooltip: "Hint",
            onPressed: () {
              setState(() {
                showHint = !showHint;
              });
            },
          ),
          PopupMenuButton<int>(
            onSelected: (size) {
              setState(() {
                gameSize = size; // 更新 state 中的 gridSize
                controller!.setGridSize(puzzleImage!.width, puzzleImage!.height,
                    gameSize); // 重新生成 pieces
              });
            },
            itemBuilder: (_) => List.generate(
              7,
              (i) => PopupMenuItem(
                value: i + 4,
                child: Text("${i + 4}"),
              ),
            ),
            icon: const Icon(
              Icons.grid_on,
              color: Colors.white,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check),
            color: Colors.white,
            onPressed: _check,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double maxWidth = constraints.maxWidth;
          double maxHeight = constraints.maxHeight;

          late double puzzleWidth;
          late double puzzleHeight;

          if (maxWidth > maxHeight) {
            maxHeight = constraints.maxHeight - 16;
            puzzleHeight = maxHeight;
            puzzleWidth = min(maxWidth * 0.75,
                maxHeight * puzzleImage!.width / puzzleImage!.height);

            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Gaps.w24,
                  SizedBox(
                    width: puzzleWidth,
                    height: puzzleHeight,
                    child: _buildPuzzleArea(
                        ctrl, puzzleWidth, puzzleHeight, puzzleImage!),
                  ),
                  Gaps.w16,
                  if (showHint)
                    Expanded(
                      child: InteractiveViewer(
                        minScale: 0.2,
                        maxScale: 5.0,
                        boundaryMargin: const EdgeInsets.all(20),
                        child: Center(
                          child: RawImage(image: puzzleImage),
                        ),
                      ),
                    ),
                  Gaps.w16,
                ],
              ),
            );
          } else {
            maxWidth = constraints.maxWidth - 16;
            puzzleWidth = maxWidth;
            puzzleHeight = min(maxHeight * 0.75,
                maxWidth / puzzleImage!.width * puzzleImage!.height);

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Gaps.h16,
                  SizedBox(
                    width: puzzleWidth,
                    height: puzzleHeight,
                    child: _buildPuzzleArea(
                        ctrl, puzzleWidth, puzzleHeight, puzzleImage!),
                  ),
                  Gaps.h16,
                  if (showHint)
                    Expanded(
                      child: InteractiveViewer(
                        minScale: 0.2,
                        maxScale: 5.0,
                        boundaryMargin: const EdgeInsets.all(20),
                        child: Center(
                          child: RawImage(image: puzzleImage),
                        ),
                      ),
                    ),
                  Gaps.h16,
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildPuzzleArea(ControllerGamePuzzleMap ctrl, double puzzleWidth,
      double puzzleHeight, ui.Image inputImage) {
    // 計算圖片在容器中的實際顯示區域
    final imageRect0 =
        _calcImageRectInBox(puzzleWidth, puzzleHeight, inputImage);

    // 想離邊界多遠（像素）
    const double padding = 24;

    final imageRect = imageRect0.deflate(padding);

    // 只使用圖片區域切格子
    final tileWidth = imageRect.width / ctrl.colsCount;
    final tileHeight = imageRect.height / ctrl.rowsCount;

    return Stack(
      children: ctrl.pieces.map((piece) {
        return AnimatedBuilder(
          animation: ctrl,
          builder: (_, __) {
            final row = piece.currentIndex ~/ ctrl.colsCount;
            final col = piece.currentIndex % ctrl.colsCount;
            Offset offset = ctrl.dragOffsets[piece.currentIndex] ?? Offset.zero;

            Widget tileChild = _buildPuzzleImage(
                piece, tileWidth, tileHeight, puzzleImage!, ctrl);

            if (piece.currentIndex != piece.correctIndex) {
              // 只有沒完成的拼圖才可拖動
              tileChild = GestureDetector(
                onPanUpdate: (details) {
                  ctrl.updateDrag(piece, details.delta);
                },
                onPanEnd: (details) {
                  ctrl.endDrag(piece, tileWidth, tileHeight);
                },
                child: tileChild,
              );
            }

            tileChild = Stack(children: [
              tileChild,
              if (piece.correctIndex != piece.currentIndex)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _GroupBorderPainter(
                        color: Colors.black87,
                        isDashed: false,
                      ),
                    ),
                  ),
                ),
              if (piece.correctIndex == piece.currentIndex)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        border: Border.all(color: Colors.yellow, width: 3),
                      ),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.green.shade800,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
            ]);

            return Positioned(
              left: imageRect.left + col * tileWidth + offset.dx,
              top: imageRect.top + row * tileHeight + offset.dy,
              width: tileWidth,
              height: tileHeight,
              child: tileChild,
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildPuzzleImage(ModelGamePuzzlePiece piece, double tileWidth,
      double tileHeight, ui.Image inputImage, ControllerGamePuzzleMap ctrl) {
    final row = piece.correctIndex ~/ ctrl.colsCount;
    final col = piece.correctIndex % ctrl.colsCount;

    final srcTileW = inputImage.width / ctrl.colsCount;
    final srcTileH = inputImage.height / ctrl.rowsCount;

    return CustomPaint(
      size: Size(tileWidth, tileHeight),
      painter: _PuzzleTilePainter(
        uiImage: inputImage,
        sourceRect: Rect.fromLTWH(
          col * srcTileW,
          row * srcTileH,
          srcTileW,
          srcTileH,
        ),
      ),
    );
  }

  Rect _calcImageRectInBox(double boxWidth, double boxHeight, ui.Image image) {
    final imageRatio = image.width / image.height;
    final boxRatio = boxWidth / boxHeight;

    double drawWidth, drawHeight;

    if (imageRatio > boxRatio) {
      drawWidth = boxWidth;
      drawHeight = boxWidth / imageRatio;
    } else {
      drawHeight = boxHeight;
      drawWidth = boxHeight * imageRatio;
    }

    final dx = (boxWidth - drawWidth) / 2;
    final dy = (boxHeight - drawHeight) / 2;

    return Rect.fromLTWH(dx, dy, drawWidth, drawHeight);
  }

  void _check() async {
    final ok = await controller!.checkResult();
    // 顯示結果
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(ok ? "Pass！🎉" : "Fail 😢"),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (ok) {
                // 強制跳轉到遊戲頁（不能跳過）
                int value = widget.gameLevel % 5;
                value == 0
                    ? await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PageGameGrammar(
                            gameId: widget.gameId,
                            gameLevel: -1, //widget.gameLevel,
                          ),
                        ),
                      )
                    : value == 4
                        ? await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PageGameSpeaking(
                                gameId: widget.gameId,
                                gameLevel: -1, //widget.gameLevel,
                              ),
                            ),
                          )
                        : value == 3
                            ? await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PageGameTranslation(
                                    gameId: widget.gameId,
                                    gameLevel: -1, //widget.gameLevel,
                                  ),
                                ),
                              )
                            : value == 2
                                ? await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PageGameSentence(
                                        gameId: widget.gameId,
                                        gameLevel: -1, //widget.gameLevel,
                                      ),
                                    ),
                                  )
                                : await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PageGameWordSearch(
                                        gameId: widget.gameId,
                                        gameLevel: -1, //widget.gameLevel,
                                      ),
                                    ),
                                  );
                Navigator.pop(context, true); // 過關 -> 返回上一頁
              }
            },
            child: Text("OK"),
          )
        ],
      ),
    );
  }
}

class _PuzzleTilePainter extends CustomPainter {
  final ui.Image uiImage;
  final Rect sourceRect;

  _PuzzleTilePainter({required this.uiImage, required this.sourceRect});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(uiImage, sourceRect,
        Rect.fromLTWH(0, 0, size.width, size.height), Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GroupBorderPainter extends CustomPainter {
  final Color color;
  final bool isDashed; // 是否虛線

  _GroupBorderPainter({required this.color, this.isDashed = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    if (!isDashed) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    } else {
      // 畫虛線矩形
      const dashWidth = 5.0;
      const dashSpace = 3.0;
      final path = Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      double distance = 0.0;
      for (final metric in path.computeMetrics()) {
        while (distance < metric.length) {
          final next = (distance + dashWidth).clamp(0.0, metric.length);
          canvas.drawPath(metric.extractPath(distance, next), paint);
          distance = next + dashSpace;
        }
        distance = 0.0; // 重置
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

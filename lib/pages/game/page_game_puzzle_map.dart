import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/game/controller_game_puzzle_map.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/game/model_game_puzzle_map.dart';
import 'package:life_pilot/pages/game/page_game_sentence.dart';
import 'package:life_pilot/pages/game/page_game_word_match.dart';
import 'package:life_pilot/services/game/service_game.dart';
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
  late ModelGamePuzzleMap map;
  late int gridSize;
  ui.Image? puzzleImage;
  ControllerGamePuzzleMap? controller;

  Map<int, Offset> dragOffsets = {}; // 用 piece.currentIndex 當 key

  @override
  void initState() {
    super.initState();
    gridSize = min(widget.gameLevel + 3, 10);
    final auth = context.read<ControllerAuth>();
    controller = ControllerGamePuzzleMap(
      userName: auth.currentAccount ?? AuthConstants.guest,
      service: ServiceGame(),
      gameId: widget.gameId,
      gameLevel: widget.gameLevel,
    );
    controller!.setGridSize(gridSize);
    final maps = [
      "assets/maps/world.png",
      "assets/maps/asia.png",
      "assets/maps/taiwan.png",
      "assets/maps/taiwan_outlying_islands.png",
      "assets/maps/penghu.png",
      "assets/maps/kinmen.png",
      "assets/maps/korea.png",
      "assets/maps/japan.png",
      "assets/maps/singapore.png"
    ];
    map = ModelGamePuzzleMap(assetPath: maps[widget.gameLevel - 1]);
    _loadImage(map.assetPath).then((img) {
      setState(() {
        puzzleImage = img;
      });
    });
  }

  Future<ui.Image> _loadImage(String path) async {
    final data = await DefaultAssetBundle.of(context).load(path);
    final list = Uint8List.view(data.buffer);
    final codec = await ui.instantiateImageCodec(list);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  List<ModelGamePuzzlePiece> _getGroup(ModelGamePuzzlePiece piece) {
    // 如果已經在正確位置，不能拖
    if (piece.currentIndex == piece.correctIndex) return [];

    /*final row = piece.currentIndex ~/ gridSize;
    List<ModelGamePuzzlePiece> rowPieces = controller!.pieces
        .where((p) => p.currentIndex ~/ gridSize == row)
        .toList();*/

    List<ModelGamePuzzlePiece> group = [piece];

    /*int left = piece.currentIndex % gridSize;
    int right = left;

    // 向左找未在正確位置但正確相鄰的拼圖
    for (int i = left - 1; i >= 0; i--) {
      try {
        final p = rowPieces.firstWhere((rp) => rp.currentIndex % gridSize == i);
        if (p.currentIndex != p.correctIndex &&
            p.correctIndex == group.first.correctIndex - 1) {
          group.insert(0, p);
        } else {
          break;
        }
      } catch (e) {
        break;
      }
    }

    // 向右找未在正確位置但正確相鄰的拼圖
    for (int i = right + 1; i < gridSize; i++) {
      try {
        final p = rowPieces.firstWhere((rp) => rp.currentIndex % gridSize == i);
        if (p.currentIndex != p.correctIndex &&
            p.correctIndex == group.last.correctIndex + 1) {
          group.add(p);
        } else {
          break;
        }
      } catch (e) {
        break;
      }
    }*/

    return group;
  }

  void _moveGroup(List<ModelGamePuzzlePiece> group, Offset totalOffset,
      double tileRowSize, double tileColumnSize) {
    if (group.isEmpty) return;

    final newIndices = <ModelGamePuzzlePiece, int>{};

    for (var p in group) {
      final col = p.currentIndex % gridSize;
      final row = p.currentIndex ~/ gridSize;

      final newCol =
          ((col * tileRowSize + totalOffset.dx + tileRowSize * 0.15) /
                  tileRowSize) //給手指 15% 的安全邊距
              .floor()
              .clamp(0, gridSize - 1);
      final newRow = ((row * tileColumnSize + totalOffset.dy) / tileColumnSize)
          .floor()
          .clamp(0, gridSize - 1);

      newIndices[p] = newRow * gridSize + newCol;
    }

    // 群組內 newIndex 不可重複
    final indexSet = <int>{};
    for (final index in newIndices.values) {
      if (!indexSet.add(index)) {
        _resetDragOffsets(group);
        return;
      }
    }

    final positionMap = {for (var p in controller!.pieces) p.currentIndex: p};

    // 撞到正確拼圖 → 整組取消
    for (var entry in newIndices.entries) {
      final target = positionMap[entry.value];
      if (target != null &&
          !group.contains(target) &&
          target.currentIndex == target.correctIndex &&
          entry.value != entry.key.currentIndex) {
        //✔ 真的要移到別人的格子 → 擋 ✔ 只是貼邊、沒換 index → 放行
        _resetDragOffsets(group);
        return;
      }
    }

    final finalIndices = <ModelGamePuzzlePiece, int>{};

    for (var entry in newIndices.entries) {
      final p = entry.key;
      final newIndex = entry.value;
      final target = positionMap[newIndex];

      if (target != null && !group.contains(target)) {
        finalIndices[target] = p.currentIndex;
      }

      finalIndices[p] = newIndex;
    }

    finalIndices.forEach((piece, index) {
      piece.currentIndex = index;
      dragOffsets[index] = Offset.zero;
    });

    setState(() {});
  }

  void _resetDragOffsets(List<ModelGamePuzzlePiece> group) {
    setState(() {
      for (var p in group) {
        dragOffsets[p.currentIndex] = Offset.zero;
      }
    });
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
        title: const Text("Puzzle map"),
        actions: [
          PopupMenuButton<int>(
            onSelected: (size) {
              setState(() {
                gridSize = size;               // 更新 state 中的 gridSize
                controller!.setGridSize(size); // 重新生成 pieces
                dragOffsets.clear();           // 清掉舊的拖動偏移
              });
            },
            itemBuilder: (_) => List.generate(
              7,
              (i) => PopupMenuItem(
                value: i + 4,
                child: Text("${i + 4}x${i + 4}"),
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
          double maxWidth = constraints.maxWidth - 48;
          double maxHeight = constraints.maxHeight - 48;

          late double puzzleWidth;
          late double puzzleHeight;

          if (maxWidth > maxHeight) {
            puzzleHeight = maxHeight;
            puzzleWidth = maxWidth * 0.75;

            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Gaps.w16,
                  SizedBox(
                    width: puzzleWidth,
                    height: puzzleHeight,
                    child: _buildPuzzleArea(
                      ctrl,
                      puzzleWidth,
                      puzzleHeight,
                      puzzleImage!
                    ),
                  ),
                  Gaps.w16,
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: RawImage(image: puzzleImage),
                    ),
                  ),
                  Gaps.w16,
                ],
              ),
            );
          } else {
            puzzleWidth = maxWidth;
            puzzleHeight = maxHeight * 0.75;

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Gaps.h16,
                  SizedBox(
                    width: puzzleWidth,
                    height: puzzleHeight,
                    child: _buildPuzzleArea(
                      ctrl,
                      puzzleWidth,
                      puzzleHeight,
                      puzzleImage!
                    ),
                  ),
                  Gaps.h16,
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: RawImage(image: puzzleImage),
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

  Widget _buildPuzzleArea(
      ControllerGamePuzzleMap ctrl, double puzzleWidth, double puzzleHeight, ui.Image inputImage) {
    // 計算圖片在容器中的實際顯示區域
    final imageRect =
        _calcImageRectInBox(puzzleWidth, puzzleHeight, inputImage);

    // 只使用圖片區域切格子
    final tileRowSize = imageRect.width / gridSize;
    final tileColumnSize = imageRect.height / gridSize;

    return Stack(
      children: ctrl.pieces.map((piece) {
        final row = piece.currentIndex ~/ gridSize;
        final col = piece.currentIndex % gridSize;
        Offset offset = dragOffsets[piece.currentIndex] ?? Offset.zero;

        return Positioned(
          left: imageRect.left + col * tileRowSize + offset.dx,
          top: imageRect.top + row * tileColumnSize + offset.dy,
          width: tileRowSize,
          height: tileColumnSize,
          child: GestureDetector(
            onPanUpdate: (details) {
              final group = _getGroup(piece);
              if (group.isEmpty) return;
              setState(() {
                for (var p in group) {
                  dragOffsets[p.currentIndex] =
                      (dragOffsets[p.currentIndex] ?? Offset.zero) +
                          details.delta;
                }
              });
            },
            onPanEnd: (details) {
              final group = _getGroup(piece);
              final totalOffset =
                  dragOffsets[piece.currentIndex] ?? Offset.zero;
              _moveGroup(group, totalOffset, tileRowSize, tileColumnSize);
            },
            child: Stack(
              children: [
                _buildPuzzleImage(piece, tileRowSize, tileColumnSize, puzzleImage!),
                if (piece.correctIndex != piece.currentIndex)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _GroupBorderPainter(
                          color: Colors.redAccent,
                          isDashed: true,
                        ),
                      ),
                    ),
                  ),
                if (piece.correctIndex == piece.currentIndex)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.4),
                              border: Border.all(
                                color: Colors.yellow,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green.shade800,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPuzzleImage(
      ModelGamePuzzlePiece piece, double tileRowSize, double tileColumnSize, ui.Image inputImage) {
    final row = piece.correctIndex ~/ gridSize;
    final col = piece.correctIndex % gridSize;

    final srcTileW = inputImage.width / gridSize;
    final srcTileH = inputImage.height / gridSize;

    return CustomPaint(
      size: Size(tileRowSize, tileColumnSize),
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
                // 強制跳轉到 WordMatch 或 sentence 遊戲頁（不能跳過）
                final result = widget.gameLevel % 2 == 0
                    ? await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PageGameWordMatch(
                            gameId: widget.gameId,
                            gameLevel: widget.gameLevel,
                          ),
                        ),
                      )
                    : await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PageGameSentence(
                            gameId: widget.gameId,
                            gameLevel: widget.gameLevel,
                          ),
                        ),
                      );
                if (result == true) {
                  // 延遲 1 秒再回上一頁，讓玩家看到 SnackBar
                  Future.delayed(const Duration(seconds: 1), () {
                    if (!mounted) return;
                    Navigator.pop(context, true); // 過關 -> 返回上一頁
                  });
                }
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

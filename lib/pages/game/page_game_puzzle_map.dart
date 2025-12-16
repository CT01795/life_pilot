import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:life_pilot/controllers/game/controller_game_puzzle_map.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/game/model_game_puzzle_map.dart';

// ignore: must_be_immutable
class PageGamePuzzleMap extends StatefulWidget {
  final String gameId;
  int? gameLevel;
  PageGamePuzzleMap({super.key, required this.gameId, this.gameLevel});

  @override
  State<PageGamePuzzleMap> createState() => _PageGamePuzzleMapState();
}

class _PageGamePuzzleMapState extends State<PageGamePuzzleMap> {
  late ModelGamePuzzleMap map;
  late int gridSize;
  late ui.Image puzzleImage;
  ControllerGamePuzzleMap? controller;

  Map<int, Offset> dragOffsets = {}; // 用 piece.currentIndex 當 key

  @override
  void initState() {
    super.initState();
    map = ModelGamePuzzleMap(assetPath: "assets/maps/taiwan.png");

    gridSize = min((widget.gameLevel ?? 1) + 3, 10);

    _loadImage(map.assetPath).then((img) {
      setState(() {
        puzzleImage = img;
        controller = ControllerGamePuzzleMap(gridSize: gridSize);
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
    //if (piece.currentIndex == piece.correctIndex) return [];

    final row = piece.currentIndex ~/ gridSize;
    List<ModelGamePuzzlePiece> rowPieces = controller!.pieces
        .where((p) => p.currentIndex ~/ gridSize == row)
        .toList();

    List<ModelGamePuzzlePiece> group = [piece];

    int left = piece.currentIndex % gridSize;
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
    }

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
    if (controller == null) {
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
                gridSize = size;
                controller = ControllerGamePuzzleMap(gridSize: gridSize);
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
          PopupMenuButton<String>(
            onSelected: (path) async {
              final img = await _loadImage(path);
              setState(() {
                map = ModelGamePuzzleMap(assetPath: path);
                puzzleImage = img;
                controller = ControllerGamePuzzleMap(gridSize: gridSize);
              });
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: "assets/maps/taiwan.png", child: Text("Taiwan")),
              const PopupMenuItem(
                  value: "assets/maps/japan.png", child: Text("Japan")),
              const PopupMenuItem(
                  value: "assets/maps/korea.png", child: Text("Korea")),
            ],
            icon: const Icon(
              Icons.public,
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
          final maxWidth = constraints.maxWidth - 32;
          final maxHeight = constraints.maxHeight - 32;

          late double puzzleWidth;
          late double puzzleHeight;

          double imageRatio = puzzleImage.width / puzzleImage.height;

          if (maxWidth > maxHeight) {
            puzzleHeight = maxHeight;
            puzzleWidth = maxWidth * 0.75;
            if (imageRatio > puzzleWidth / puzzleHeight) {
              puzzleHeight = puzzleWidth / imageRatio;
            } else {
              puzzleWidth = puzzleHeight * imageRatio;
            }

            // 剩餘給左邊
            double remainHeight = maxHeight;
            double remainWidth = maxWidth - puzzleWidth;
            if (imageRatio > remainWidth / remainHeight) {
              remainHeight = remainWidth / imageRatio;
            } else {
              remainWidth = remainHeight * imageRatio;
            }
            return Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: remainWidth,
                    height: remainHeight,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: RawImage(image: puzzleImage),
                    ),
                  ),
                  Gaps.w16,
                  SizedBox(
                    width: puzzleWidth,
                    height: puzzleHeight,
                    child: _buildPuzzleArea(
                      ctrl,
                      puzzleWidth,
                      puzzleHeight,
                    ),
                  ),
                ],
              ),
            );
          } else {
            puzzleWidth = maxWidth;
            puzzleHeight = maxHeight * 0.75;
            if (imageRatio > puzzleWidth / puzzleHeight) {
              puzzleHeight = puzzleWidth / imageRatio;
            } else {
              puzzleWidth = puzzleHeight * imageRatio;
            }

            // 剩餘給左邊
            double remainWidth = maxWidth;
            double remainHeight = maxHeight - puzzleHeight;
            if (imageRatio > remainWidth / remainHeight) {
              remainHeight = remainWidth / imageRatio;
            } else {
              remainWidth = remainHeight * imageRatio;
            }
            
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start, // 改成靠上
                crossAxisAlignment: CrossAxisAlignment.center, // 水平置中
                children: [
                  Gaps.h16,
                  SizedBox(
                    width: remainWidth,
                    height: remainHeight,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: RawImage(image: puzzleImage),
                    ),
                  ),
                  Gaps.h16,
                  SizedBox(
                    width: puzzleWidth,
                    height: puzzleHeight,
                    child: _buildPuzzleArea(
                      ctrl,
                      puzzleWidth,
                      puzzleHeight,
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildPuzzleArea(
      ControllerGamePuzzleMap ctrl, double puzzleWidth, double puzzleHeight) {
    final tileRowSize = puzzleWidth / gridSize;
    final tileColumnSize = puzzleHeight / gridSize;

    return Stack(
      children: ctrl.pieces.map((piece) {
        final row = piece.currentIndex ~/ gridSize;
        final col = piece.currentIndex % gridSize;
        Offset offset = dragOffsets[piece.currentIndex] ?? Offset.zero;

        return Positioned(
          left: col * tileRowSize + offset.dx,
          top: row * tileColumnSize + offset.dy,
          width: tileRowSize,
          height: tileColumnSize,
          child: GestureDetector(
            onPanUpdate: (details) {
              final group = _getGroup(piece);
              if (group.isEmpty) return; // 正確位置的拼圖不處理
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
                _buildPuzzleImage(piece, tileRowSize, tileColumnSize),
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
                          // 半透明底 + 黃框
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              border: Border.all(
                                color: Colors.yellow,
                              ),
                            ),
                          ),

                          // ✔ 打勾
                          const Positioned(
                            right: 6,
                            bottom: 6,
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
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
      ModelGamePuzzlePiece piece, double tileRowSize, double tileColumnSize) {
    final row = piece.correctIndex ~/ gridSize;
    final col = piece.correctIndex % gridSize;

    return CustomPaint(
      size: Size(tileRowSize, tileColumnSize),
      painter: _PuzzleTilePainter(
        uiImage: puzzleImage,
        sourceRect: Rect.fromLTWH(col * tileRowSize, row * tileColumnSize,
            tileRowSize, tileColumnSize),
      ),
    );
  }

  void _check() {
    final ok = controller!.checkResult();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(ok ? "🎉 Correct!" : "❌ Not yet"),
        content: Text(ok
            ? "Puzzle completed successfully!"
            : "Some pieces are still in the wrong position."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("OK")),
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

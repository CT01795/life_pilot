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

  final double puzzleAreaSize = 512;
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
    if (piece.currentIndex == piece.correctIndex) return [];

    final row = piece.currentIndex ~/ gridSize;
    List<ModelGamePuzzlePiece> rowPieces =
        controller!.pieces.where((p) => p.currentIndex ~/ gridSize == row).toList();

    List<ModelGamePuzzlePiece> group = [piece];

    int left = piece.currentIndex % gridSize;
    int right = left;

    // 向左找未在正確位置但正確相鄰的拼圖
    for (int i = left - 1; i >= 0; i--) {
      try {
        final p = rowPieces.firstWhere((rp) => rp.currentIndex % gridSize == i);
        if (p.currentIndex != p.correctIndex && p.correctIndex == group.first.correctIndex - 1) {
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
        if (p.currentIndex != p.correctIndex && p.correctIndex == group.last.correctIndex + 1) {
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

  void _moveGroup(List<ModelGamePuzzlePiece> group, Offset totalOffset) {
    final tileSize = puzzleAreaSize / gridSize;

    // 計算群組拼圖的新位置
    Map<ModelGamePuzzlePiece, int> newIndices = {};
    for (var p in group) {
      final col = p.currentIndex % gridSize;
      final row = p.currentIndex ~/ gridSize;

      final newCol =
          ((col * tileSize + totalOffset.dx) / tileSize).round().clamp(0, gridSize - 1);
      final newRow =
          ((row * tileSize + totalOffset.dy) / tileSize).round().clamp(0, gridSize - 1);
      final newIndex = newRow * gridSize + newCol;
      newIndices[p] = newIndex;
    }

    // 建立 index -> 拼圖映射
    Map<int, ModelGamePuzzlePiece?> positionMap = {};
    for (var p in controller!.pieces) {
      positionMap[p.currentIndex] = p;
    }

    // 處理互換：先把 target 拼圖的 currentIndex 存起來，最後再統一更新
    Map<ModelGamePuzzlePiece, int> finalIndices = {};

    for (var entry in newIndices.entries) {
      final p = entry.key;
      final newIndex = entry.value;

      final target = positionMap[newIndex];

      if (target != null && !group.contains(target) && target.currentIndex != target.correctIndex) {
        // 互換位置
        finalIndices[target] = p.currentIndex; // 先存 target 的新位置
      }

      finalIndices[p] = newIndex; // 存群組拼圖的新位置
    }

    // 統一更新所有拼圖
    finalIndices.forEach((piece, index) {
      piece.currentIndex = index;
      dragOffsets[index] = Offset.zero;
    });

    setState(() {});
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
            icon: const Icon(Icons.grid_on),
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
            ],
            icon: const Icon(Icons.public),
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _check,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth - 16;
          final maxHeight = constraints.maxHeight - 16;

          final puzzleSize = min(maxWidth, maxHeight);
          double mainSize;
          Widget mainImage;
          Widget puzzleArea = SizedBox(
            width: puzzleSize,
            height: puzzleSize,
            child: _buildPuzzleArea(ctrl, puzzleSize),
          );

          if (maxWidth > maxHeight) {
            mainSize = min(maxWidth - maxHeight, maxHeight);
            mainImage = SizedBox(
              width: mainSize,
              height: mainSize,
              child: FittedBox(
                fit: BoxFit.contain,
                child: RawImage(image: puzzleImage),
              ),
            );
            return Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  mainImage,
                  Gaps.w16,
                  puzzleArea,
                ],
              ),
            );
          } else {
            mainSize = min(maxHeight - maxWidth, maxWidth);
            mainImage = SizedBox(
              width: mainSize,
              height: mainSize,
              child: FittedBox(
                fit: BoxFit.contain,
                child: RawImage(image: puzzleImage),
              ),
            );
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  mainImage,
                  Gaps.h16,
                  puzzleArea,
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildPuzzleArea(ControllerGamePuzzleMap ctrl, double puzzleAreaSize) {
    final tileSize = puzzleAreaSize / gridSize;

    return Stack(
      children: ctrl.pieces.map((piece) {
        final row = piece.currentIndex ~/ gridSize;
        final col = piece.currentIndex % gridSize;
        Offset offset = dragOffsets[piece.currentIndex] ?? Offset.zero;

        return Positioned(
          left: col * tileSize + offset.dx,
          top: row * tileSize + offset.dy,
          width: tileSize,
          height: tileSize,
          child: GestureDetector(
            onPanUpdate: (details) {
              final group = _getGroup(piece);
               if (group.isEmpty) return; // 正確位置的拼圖不處理
              setState(() {
                for (var p in group) {
                  dragOffsets[p.currentIndex] =
                      (dragOffsets[p.currentIndex] ?? Offset.zero) + details.delta;
                }
              });
            },
            onPanEnd: (details) {
              final group = _getGroup(piece);
              final totalOffset = dragOffsets[piece.currentIndex] ?? Offset.zero;
              _moveGroup(group, totalOffset);
            },
            child: Stack(
              children: [
                _buildPuzzleImage(piece, tileSize),
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
                      child: Container(
                        color: Colors.green.withValues(alpha: 0.2),
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

  Widget _buildPuzzleImage(ModelGamePuzzlePiece piece, double tileSize) {
    final row = piece.correctIndex ~/ gridSize;
    final col = piece.correctIndex % gridSize;

    return CustomPaint(
      size: Size(tileSize, tileSize),
      painter: _PuzzleTilePainter(
        uiImage: puzzleImage,
        sourceRect: Rect.fromLTWH(col * tileSize, row * tileSize, tileSize, tileSize),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
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
    canvas.drawImageRect(uiImage, sourceRect, Rect.fromLTWH(0, 0, size.width, size.height), Paint());
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
      final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
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
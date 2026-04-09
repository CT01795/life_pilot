import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/game/mario_translation/word_item.dart';
import 'package:provider/provider.dart';

import 'player.dart';
import 'enemy.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/game/mario_translation/controller_game_mario_translation.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/utils/const.dart';

class PageGameMarioTranslation extends FlameGame
    with HasCollisionDetection, HasKeyboardHandlerComponents {
  List<WordItem> optionItems = [];
  double yy = 600;
  late Player player;
  late ControllerGameMarioTranslation controller;
  final BuildContext context;
  final String gameId;
  final int gameLevel;
  late TextComponent questionText;

  // 世界大小
  final double worldWidth = 2000;
  final double worldHeight = 500;

  PageGameMarioTranslation({
    required this.context,
    required this.gameId,
    required this.gameLevel,
  });

  @override
  Color backgroundColor() => const Color(0xFF87CEEB); // 天空藍

  @override
  Future<void> onLoad() async {
    final auth = context.read<ControllerAuth>();
    controller = ControllerGameMarioTranslation(
      gameId: gameId,
      gameLevel: gameLevel,
      userName: auth.currentAccount ?? AuthConstants.guest,
      service: ServiceGame(),
      maxQuestions: gameLevel == -1 ? 10 : 999,
    );
    await controller.loadNextQuestion();

    // 地板
    add(RectangleComponent(
      position: Vector2(0, yy+50),
      size: Vector2(worldWidth, 50),
      paint: Paint()..color = const Color(0xFF8B4513),
    ));

    // 玩家
    player = Player(position: Vector2(100, yy), size: Vector2(50, 50));
    add(player);

    // 題目 HUD
    questionText = TextComponent(
      text: controller.currentQuestion != null
          ? "翻譯：${controller.currentQuestion!.question}"
          : "載入中...",
      position: Vector2(40, 100),
      anchor: Anchor.topLeft,
      priority: 100,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 24,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    // ⭐ 設定為 HUD（固定在畫面上）
    add(questionText);

    // 敵人
    spawnEnemy();
  }

  void spawnEnemy() {
    add(Enemy(
      position: Vector2(600, yy),
      size: Vector2(50, 50),
      onStomp: () {
        spawnOptions();
      },
    ));
  }

  bool isAnswering = false;

  void spawnOptions() {
    if (isAnswering) return;
    final q = controller.currentQuestion;
    if (q == null) return;

    isAnswering = true;
    for (int i = 0; i < q.options.length; i++) {
      late final WordItem item;
      item = WordItem(
        word: q.options[i],
        onHitByBullet: () {
          optionItems.remove(item); // 刪除列表
          item.removeFromParent(); // 刪除畫面
        },
        position: player.position + Vector2(120, -100 - i * 100),
        onCollect: (word) async {
          controller.answer(word);

          if (word == q.correctAnswer) {
            for (var o in optionItems) {
              o.removeFromParent();
            }

            isAnswering = false;
            await controller.loadNextQuestion();
            questionText.text =
                "翻譯：${controller.currentQuestion?.question ?? ''}\n分數：${controller.score}";
            spawnEnemy();
          } else {
            for (var o in optionItems) {
              if (o.word == word) {
                o.removeFromParent();
                optionItems.remove(o);
                break;
              }
            }
            if (optionItems.isEmpty) {
              isAnswering = false;
              await controller.loadNextQuestion();
              questionText.text =
                  "翻譯：${controller.currentQuestion?.question ?? ''}\n分數：${controller.score}";
              spawnEnemy();
            }
            questionText.text = "翻譯：${q.question}\n分數：${controller.score}";
          }
        },
      )..priority = 10;
      optionItems.add(item);
      add(item);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 鏡頭跟隨玩家 (Flame 1.35.1 官方做法)
    final viewport = camera.viewport;
    if (viewport is FixedResolutionViewport) {
      final halfWidth = viewport.resolution.x / 2;
      final halfHeight = viewport.resolution.y / 2;

      camera.viewfinder.position = Vector2(
        (player.position.x - halfWidth)
            .clamp(0, worldWidth - viewport.resolution.x),
        (player.position.y - halfHeight)
            .clamp(0, worldHeight - viewport.resolution.y),
      );
    }
  }
}

// ignore_for_file: deprecated_member_use

import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/game/mario_translation/question_display.dart';
import 'package:life_pilot/game/mario_translation/word_item.dart';
import 'package:provider/provider.dart';

import 'player.dart';
import 'enemy.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/game/mario_translation/controller_game_mario_translation.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/utils/const.dart';

class PageGameMarioTranslation extends FlameGame
    with HasCollisionDetection, HasKeyboardHandlerComponents, TapCallbacks {
  List<WordItem> optionItems = [];
  late double sizeX;
  late double sizeY;
  late Player player;
  late RectangleComponent ground;
  late ControllerGameMarioTranslation controller;
  final BuildContext context;
  final String gameId;
  final int gameLevel;
  late QuestionDisplay questionTitle;
  late QuestionDisplay questionText;
  late QuestionDisplay scoreText;

  // 世界大小
  double screenW = 800;
  double screenH = 500;

  PageGameMarioTranslation({
    required this.context,
    required this.gameId,
    required this.gameLevel,
  });

  @override
  Color backgroundColor() => GameColors.sky; // 天空藍

  void layoutByScreen() {
    if (!isLoaded) return; // ⭐ 防止還沒 onLoad 就執行

    final groundY = screenH - sizeY;

    // ⭐ 地板
    ground.position = Vector2(0, groundY);
    ground.size = Vector2(screenW, sizeX);

    // ⭐ Player
    player.position.y = groundY - sizeX;

    // ⭐ Enemy（如果存在）
    for (final e in children.whereType<Enemy>()) {
      e.position.y = player.position.y;
      e.position.x = screenW * 2 / 3;
    }

    int i = 0;
    for (final e in children.whereType<WordItem>()) {
      e.position.y = player.position.y - (i + 1) * 120;
      e.position.x = screenW / 2;
      i = i + 1;
    }
  }

  @override
  Future<void> onLoad() async {
    screenW = camera.viewport.size.x;
    screenH = camera.viewport.size.y;
    sizeX = 50;
    sizeY = 200;
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
    ground = RectangleComponent(
      position: Vector2(0, screenH - sizeY),
      size: Vector2(screenW, sizeX),
      paint: Paint()..color = GameColors.ground,
    );

    add(ground);

    // 玩家
    player = Player(
        position: Vector2(sizeX + 50, ground.position.y - sizeX),
        size: Vector2(sizeX, sizeX));
    add(player);

    add(RectangleComponent(
      size: Vector2(max(screenW, screenH), 90),
      paint: Paint()..color = GameColors.hud,
    ));

    // 分數 HUD
    scoreText = QuestionDisplay(
        text: "分數: ${controller.score}",
        controller: controller,
        positionX: 40,
        positionY: 50,
        sizeX: max(screenW, screenH),
        sizeY: sizeX)
      ..priority = 100;

    // ⭐ 設定為 HUD（固定在畫面上）
    add(scoreText);

    // 題目 HUD
    questionTitle = QuestionDisplay(
        text: "題目: ",
        controller: controller,
        positionX: 40,
        positionY: 100,
        sizeX: 100,
        sizeY: sizeX)
      ..priority = 90;

    // ⭐ 設定為 HUD（固定在畫面上）
    add(questionTitle);

    // 題目 HUD
    questionText = QuestionDisplay(
        text: controller.currentQuestion?.question ?? "載入中...",
        controller: controller,
        positionX: 120,
        positionY: 100,
        sizeX: max(screenW, screenH),
        sizeY: sizeX)
      ..priority = 100;

    // ⭐ 設定為 HUD（固定在畫面上）
    add(questionText);

    layoutByScreen(); // ⭐ 初始化位置
  }

  @override
  void onMount() {
    super.onMount();
    spawnEnemy();
  }

  void spawnEnemy() {
    if (children.whereType<Enemy>().isNotEmpty) return;
    player.position.x = sizeX;
    add(Enemy(
      position: Vector2(screenW * 2 / 3, player.position.y),
      size: Vector2(sizeX, sizeX),
      onStomp: () {
        spawnOptions();
      },
    ));
  }

  bool isAnswering = false;

  Future<void> shoot() async {
    player.shoot();
  }

  void spawnOptions() {
    if (isAnswering) return;
    final q = controller.currentQuestion;
    if (q == null) return;

    isAnswering = true;

    for (int i = 0; i < q.options.length; i++) {
      late final WordItem item;
      item = WordItem(
        controller: controller,
        word: q.options[i],
        onHitByBullet: () async {
          optionItems.remove(item); // 刪除列表
          item.removeFromParent(); // 刪除畫面
          if (optionItems.isEmpty) {
            nextRound();
          }
        },
        position: Vector2(screenW / 2, player.position.y - (i + 1) * 120),
        onCollect: (word) async {
          bool isRightAnswer = await controller.answer(word);

          if (isRightAnswer) {
            for (var o in optionItems) {
              o.removeFromParent();
            }

            nextRound();
          } else {
            optionItems.removeWhere((o) {
              if (o.word == word) {
                o.removeFromParent();
                return true;
              }
              return false;
            });
            if (optionItems.isEmpty) {
              nextRound();
            }
            questionText.updateText(q.question);
            scoreText.updateText("分數: ${controller.score}");
          }
          if (controller.score >= 100 || controller.score < -20) {
            Future.microtask(() => Navigator.pop(context, true));
          }
        },
      )..priority = 10;
      optionItems.add(item);
      add(item);
    }
  }

  Future<void> nextRound() async {
    isAnswering = false;
    await controller.loadNextQuestion();

    questionText.updateText(controller.currentQuestion?.question ?? '');
    scoreText.updateText("分數: ${controller.score}");

    spawnEnemy();
  }

  /*@override
  void update(double dt) {
    super.update(dt);

    // 鏡頭跟隨玩家 (Flame 1.35.1 官方做法)
    final viewport = camera.viewport;
    if (viewport is FixedResolutionViewport) {
      final halfWidth = viewport.resolution.x / 2;
      final halfHeight = viewport.resolution.y / 2;

      camera.viewfinder.position = Vector2(
        (player.position.x - halfWidth)
            .clamp(0, screenW - viewport.resolution.x),
        (player.position.y - halfHeight)
            .clamp(0, screenH - viewport.resolution.y),
      );
    }
  }*/

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    screenW = size.x;
    screenH = size.y;

    if (isLoaded) {
      layoutByScreen(); // ⭐ 用新的 screenW / screenH
    }
  }
}

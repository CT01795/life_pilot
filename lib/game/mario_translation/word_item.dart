// ignore_for_file: deprecated_member_use

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/game/mario_translation/controller_game_mario_translation.dart';
import 'package:life_pilot/game/mario_translation/page_game_mario_translation.dart';
import 'package:life_pilot/game/mario_translation/player.dart';

class WordItem extends PositionComponent with CollisionCallbacks, HasGameRef<PageGameMarioTranslation>, TapCallbacks {
  final String word;
  final Function(String) onCollect;
  final VoidCallback? onHitByBullet;
  final ControllerGameMarioTranslation controller;
  double yy = 600;

  WordItem({
    required this.controller,
    required this.word,
    required this.onHitByBullet,
    required Vector2 position,
    required this.onCollect,
  }) : super(
          position: position,
          size: Vector2(100, 50), // ⭐ 一定要有
        );

  @override
  void onTapDown(TapDownEvent event) {
    controller.speak(word); // 點擊就播音
    super.onTapDown(event);
  }

  Future<void> hitByBullet() async {
    onHitByBullet?.call();
    removeFromParent();
  }

  @override
  Future<void> onLoad() async {
    // 白底
    add(RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.white,
    ));

    // 文字，自動換行
    final textPaint = TextPaint(
      style: const TextStyle(
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );

    add(TextBoxComponent(
      text: word,
      textRenderer: textPaint,
      boxConfig: TextBoxConfig(
        maxWidth: size.x, // 限制寬度，文字自動換行/ 可選，最多 3 行
      ),
      anchor: Anchor.center,
      position: size / 2,
    ));

    // 碰撞
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += 20 * dt;

    // ⭐ 限制 X 不超出
    position.x = position.x.clamp(0, gameRef.worldWidth - size.x);

    // ⭐ 掉到地板停止
    if (position.y >= yy) {
      position.y = yy;
    }
  }

  bool collected = false;

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (collected) return;

    if (other is Player) {
      collected = true;
      onCollect(word);
      removeFromParent();
    }
  }
}

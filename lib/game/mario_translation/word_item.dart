// ignore_for_file: deprecated_member_use

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/game/mario_translation/controller_game_mario_translation.dart';
import 'package:life_pilot/game/mario_translation/mario_text_component.dart';
import 'package:life_pilot/game/mario_translation/page_game_mario_translation.dart';
import 'package:life_pilot/game/mario_translation/player.dart';
import 'package:life_pilot/utils/const.dart';

class WordItem extends PositionComponent
    with
        CollisionCallbacks,
        HasGameRef<PageGameMarioTranslation>,
        TapCallbacks {
  final String word;
  final Function(String) onCollect;
  final VoidCallback? onHitByBullet;
  final ControllerGameMarioTranslation controller;
  double get playerFixedY => gameRef.ground.position.y - gameRef.sizeX;

  WordItem({
    required this.controller,
    required this.word,
    required this.onHitByBullet,
    required Vector2 position,
    required this.onCollect,
  }) : super(
         position: position,
         size: Vector2(200, 50), // ⭐ 一定要有
       );

  @override
  void onTapDown(TapDownEvent event) {
    controller.speak(word); // 點擊就播音
    super.onTapDown(event);
  }

  bool isRemovedQ = false;

  void hitByBullet() {
    if (isRemovedQ || collected) return;
    isRemovedQ = true;
    removeFromParent();
    onHitByBullet?.call();
  }

  @override
  Future<void> onLoad() async {
    final label = MarioTextComponent(
      text: word,
      maxWidth: size.x,
      padding: const EdgeInsets.all(8),
      style: const TextStyle(
        color: GameColors.textItemDark,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      anchor: Anchor.center,
    );
    if (label.height > size.y) size.y = label.height;
    label.position = size / 2;
    // 白底
    add(
      RectangleComponent(
        size: size,
        paint: Paint()
          ..color = GameColors.card
          ..style = PaintingStyle.fill,
      ),
    );

    add(
      RectangleComponent(
        size: size,
        paint: Paint()
          ..color = Colors.white.withOpacity(0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      ),
    );

    add(label);

    // 碰撞
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += 15 * dt;

    // ⭐ 限制 X 不超出
    position.x = position.x.clamp(0, gameRef.screenW - size.x);

    // ⭐ 掉到地板停止
    if (position.y >= playerFixedY) {
      position.y = playerFixedY;
    }
  }

  bool collected = false;

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (isRemovedQ) return;
    if (collected) return;

    if (other is Player) {
      collected = true;
      isRemovedQ = true;
      if (isMounted) {
        removeFromParent();
      }
      onCollect(word);
    }
  }
}

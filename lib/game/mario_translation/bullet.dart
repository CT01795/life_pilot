// ignore_for_file: deprecated_member_use

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/game/mario_translation/page_game_mario_translation.dart';
import 'package:life_pilot/game/mario_translation/word_item.dart';
import 'package:life_pilot/utils/const.dart';

class Bullet extends CircleComponent with CollisionCallbacks, HasGameRef<PageGameMarioTranslation> {
  final double speed;
  late final Vector2 velocity;
  Bullet({
    required Vector2 position,
    required Vector2 direction,
    this.speed = 300,
  }) : super(
          position: position,
          radius: 8,
          paint: Paint()
            ..shader = RadialGradient(
              colors: [
                GameColors.bullet.withOpacity(1),
                GameColors.bullet.withOpacity(0.2),
              ],
            ).createShader(Rect.fromCircle(center: Offset.zero, radius: 10)),
          priority: 20,
        ){
    velocity = direction.normalized() * speed;
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * dt;

    // ⭐ 邊界刪除
    if (position.x < 0 ||
        position.x > gameRef.screenW ||
        position.y < 0 ||
        position.y > gameRef.screenH) {
      if (isMounted) {
        removeFromParent();
      }
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is WordItem) {
      other.hitByBullet();
      if (isMounted) {
        removeFromParent();
      }
    }
  }
}
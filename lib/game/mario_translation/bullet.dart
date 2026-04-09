import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/game/mario_translation/page_game_mario_translation.dart';
import 'package:life_pilot/game/mario_translation/word_item.dart';

// ignore: deprecated_member_use
class Bullet extends CircleComponent with CollisionCallbacks, HasGameRef<PageGameMarioTranslation> {
  final Vector2 direction;
  final double speed;
  double yy = 600;
  Bullet({
    required Vector2 position,
    required this.direction,
    this.speed = 300,
  }) : super(
          position: position,
          radius: 8,
          paint: Paint()..color = Colors.red,
          priority: 20,
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += direction.normalized() * speed * dt;

    final game = gameRef;

    // ⭐ 邊界刪除
    if (position.x < 0 ||
        position.x > game.worldWidth ||
        position.y < 0 ||
        position.y > game.worldHeight) {
      removeFromParent();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is WordItem) {
      other.hitByBullet();
      removeFromParent();
    }
  }
}
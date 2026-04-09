import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:life_pilot/game/mario_translation/page_game_mario_translation.dart';
import 'package:life_pilot/game/mario_translation/player.dart';

class Enemy extends SpriteComponent with CollisionCallbacks {
  Vector2 velocity = Vector2(-100, 0);

  final VoidCallback onStomp;
  
  Enemy({required super.position, required super.size,
    required this.onStomp});

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('enemy.png'); 
    add(RectangleHitbox());
    super.onLoad();
  }

  bool isDead = false;

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (isDead) return;
    if (other is Player && other.velocity.y > 0) {
      isDead = true;
      other.velocity.y = -100; // ⭐ 踩到反彈
      onStomp(); // 被踩
      removeFromParent();
    }
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * dt;

    final game = parent as PageGameMarioTranslation;

    if (position.x <= 0) {
      position.x = 0;
      velocity.x = velocity.x.abs();
    }

    if (position.x >= game.worldWidth - size.x) {
      position.x = game.worldWidth - size.x;
      velocity.x = -velocity.x.abs();
    }
  }
}
// ignore_for_file: deprecated_member_use
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/game/mario_translation/bullet.dart';
import 'package:life_pilot/game/mario_translation/page_game_mario_translation.dart';
import 'package:life_pilot/game/mario_translation/player.dart';

class Enemy extends SpriteComponent with CollisionCallbacks, HasGameRef<PageGameMarioTranslation> {
  Vector2 velocity = Vector2(-100, 0);

  final VoidCallback onStomp;
  double hitCooldown = 0;

  Enemy({required super.position, required super.size, required this.onStomp});

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
    // ⭐ 被子彈打中
    if (other is Bullet) {
      isDead = true;

      // 移除子彈
      other.removeFromParent();
      // ⭐ 效果：像被踩一樣
      onStomp();
      if (isMounted) {
        removeFromParent();
      }
    }

    else if (other is Player) {
      if (other.velocity.y > 0) {
        // ✅ 踩到敵人
        isDead = true;
        other.velocity.y = -100; // 反彈
        onStomp();
        if (isMounted) {
          removeFromParent();
        }
      } else {
        if (hitCooldown <= 0) {
          hitCooldown = 1.5; // 1.5秒內不再扣分
          // ❌ 被敵人撞到（不是從上面踩）
          gameRef.controller.score -= 4;
          other.hitEffect(); // ⭐ 玩家閃爍

          // 更新畫面文字
          gameRef.questionText.updateText(
              gameRef.controller.currentQuestion?.question ?? '');
          gameRef.scoreText.updateText(
              "分數：${gameRef.controller.score}");
          if (gameRef.controller.score < -20) {
            Future.microtask(() => Navigator.pop(gameRef.context, true));
          }
        }
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    hitCooldown -= dt;
    position += velocity * dt;

    if (position.x <= 0) {
      position.x = 0;
      velocity.x = velocity.x.abs();
    }

    if (position.x >= gameRef.screenW - size.x) {
      position.x = gameRef.screenW - size.x;
      velocity.x = -velocity.x.abs();
    }
    // ⭐ 限制左右邊界
    position.x = position.x.clamp(0, gameRef.screenW - size.x);
    position.y = gameRef.screenH - gameRef.sizeY - gameRef.sizeX;
  }
}

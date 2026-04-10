import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:life_pilot/game/mario_translation/bullet.dart';
import 'package:life_pilot/game/mario_translation/page_game_mario_translation.dart';

// ignore: deprecated_member_use
class Player extends SpriteComponent with KeyboardHandler, HasGameRef<PageGameMarioTranslation> {
  Vector2 velocity = Vector2.zero();
  final double speed = 200;
  final double jumpSpeed = -400;
  bool isOnGround = true;
  int facing = 1; // 1 = 右, -1 = 左
  bool isInvincible = false;
  double blinkTimer = 0;
  double blinkDuration = 1.5; // 閃爍總時間
  double blinkInterval = 0.1; // 閃爍速度

  Player({required super.position, required super.size});
  double get playerFixedY => gameRef.ground.position.y - gameRef.sizeX;

  void moveLeft(bool pressed) {
    if (pressed) {
      velocity.x = -speed;
      facing = -1;
    } else {
      velocity.x = 0;
    }
  }

  void moveRight(bool pressed) {
    if (pressed) {
      velocity.x = speed;
      facing = 1;
    } else {
      velocity.x = 0;
    }
  }

  void jump() {
    if (isOnGround) {
      velocity.y = jumpSpeed;
      isOnGround = false;
    }
  }

  void shoot() {
    final bullet = Bullet(
      position: position + Vector2(size.x / 2, size.y / 2),
      direction: Vector2(facing.toDouble(), 0), // ⭐ 左右
    );
    gameRef.add(bullet);
  }

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('player.png');
    add(RectangleHitbox());
    super.onLoad();
  }

  void hitEffect() {
    isInvincible = true;
    blinkTimer = 0;
  }

  double shootCooldown = 0;
  
  @override
  void update(double dt) {
    super.update(dt);
    shootCooldown -= dt;
    velocity.y += 800 * dt; // 重力
    position += velocity * dt;

    if (position.y >= playerFixedY) {
      // 地面
      position.y = playerFixedY;
      velocity.y = 0;
      isOnGround = true;
    }
    // ⭐ 限制左右邊界
    position.x = position.x.clamp(0, gameRef.screenW - size.x);

    // ⭐ 閃爍邏輯
    if (isInvincible) {
      blinkTimer += dt;

      // 每 0.1 秒切換顯示/隱藏
      if ((blinkTimer / blinkInterval).floor() % 2 == 0) {
        opacity = 0.2;
      } else {
        opacity = 1.0;
      }

      if (blinkTimer >= blinkDuration) {
        isInvincible = false;
        opacity = 1.0; // 還原
      }
    }
  }

  @override
  // ignore: deprecated_member_use
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    velocity.x = 0;
    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
      velocity.x = -speed;
    }
    if (keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
      velocity.x = speed;
    }
    if (keysPressed.contains(LogicalKeyboardKey.space) && isOnGround) {
      velocity.y = jumpSpeed;
      isOnGround = false;
    }
    if (keysPressed.contains(LogicalKeyboardKey.keyZ) && shootCooldown <= 0) {
      shoot(); // 🔹 按 Z 射擊
      shootCooldown = 0.3;
    }
    return true;
  }
}

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:life_pilot/game/mario_translation/bullet.dart';

// ignore: deprecated_member_use
class Player extends SpriteComponent with HasGameRef, KeyboardHandler {
  Vector2 velocity = Vector2.zero();
  double yy = 700;
  final double speed = 200;
  final double jumpSpeed = -400;
  bool isOnGround = true;

  Player({required super.position, required super.size});

  void moveLeft(bool pressed) {
    velocity.x = pressed ? -speed : 0;
  }

  void moveRight(bool pressed) {
    velocity.x = pressed ? speed : 0;
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
      direction: Vector2(1, 0), // 向右射
    );
    gameRef.add(bullet);
  }

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('player.png');
    add(RectangleHitbox());
    super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    velocity.y += 800 * dt; // 重力
    position += velocity * dt;

    if (position.y >= yy) {
      // 地面
      position.y = yy;
      velocity.y = 0;
      isOnGround = true;
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
    if (keysPressed.contains(LogicalKeyboardKey.keyZ)) {
      shoot(); // 🔹 按 Z 射擊
    }
    return true;
  }
}

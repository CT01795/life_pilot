// 新增一個 QuestionDisplay 元件
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/game/mario_translation/controller_game_mario_translation.dart';

class QuestionDisplay extends PositionComponent with TapCallbacks {
  final ControllerGameMarioTranslation controller;
  String text;

  QuestionDisplay({required this.text, required this.controller})
      : super(position: Vector2(40, 100), size: Vector2(500, 50));

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // 顯示文字
    add(TextComponent(
      text: text,
      anchor: Anchor.topLeft,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 24,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    ));

    // 加碰撞盒，才能感應點擊
    add(RectangleHitbox());
  }

  @override
  void onTapDown(TapDownEvent event) {
    controller.speak(text); // 點擊播放
    super.onTapDown(event);
  }

  // 方便更新文字
  void updateText(String newText) {
    text = newText;
    children.whereType<TextComponent>().first.text = newText;
  }
}
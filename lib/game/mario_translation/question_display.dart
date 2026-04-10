// 新增一個 QuestionDisplay 元件
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/game/mario_translation/controller_game_mario_translation.dart';

class QuestionDisplay extends PositionComponent with TapCallbacks {
  final ControllerGameMarioTranslation controller;
  String text;
  double positionX;
  double positionY;
  double sizeX;
  double sizeY;


  QuestionDisplay(
      {required this.text, required this.controller, required this.positionX, required this.positionY,
        required this.sizeX, required this.sizeY,})
      : super(position: Vector2(positionX, positionY), size: Vector2(sizeX, sizeY));

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // 顯示文字
    add(TextComponent(
      text: text,
      anchor: Anchor.topLeft,
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: 32,
          color: text.contains("分數") ? Colors.red : Colors.black,
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
    final textComp = children.whereType<TextComponent>().firstOrNull;
    textComp?.text = newText;
  }
}

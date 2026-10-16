// 新增一個 QuestionDisplay 元件
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/game/mario_translation/controller_game_mario_translation.dart';
import 'package:life_pilot/game/mario_translation/mario_text_component.dart';
import 'package:life_pilot/utils/const.dart';

class QuestionDisplay extends PositionComponent with TapCallbacks {
  final ControllerGameMarioTranslation controller;
  String text;
  double positionX;
  double positionY;
  double sizeX;
  double sizeY;
  final bool isEmphasized;
  MarioTextComponent? _label;

  QuestionDisplay({
    required this.text,
    required this.controller,
    required this.positionX,
    required this.positionY,
    required this.sizeX,
    required this.sizeY,
    this.isEmphasized = false,
  }) : super(
         position: Vector2(positionX, positionY),
         size: Vector2(sizeX, sizeY),
       ) {
    // Measure immediately so the HUD can position the next row below wrapped text.
    final label = _label = MarioTextComponent(
      text: text,
      anchor: Anchor.topLeft,
      maxWidth: sizeX,
      padding: const EdgeInsets.all(8),
      style: TextStyle(
        fontSize: 32,
        color: isEmphasized ? GameColors.ground : GameColors.textDark,
        fontWeight: FontWeight.bold,
      ),
    );
    if (label.height > size.y) size.y = label.height;
    add(label);
  }

  @override
  void onTapDown(TapDownEvent event) {
    final question = controller.currentQuestion;
    if (question != null) controller.speak(question.question);
    super.onTapDown(event);
  }

  // 方便更新文字
  void updateText(String newText) {
    text = newText;
    final label = _label;
    if (label == null) return;
    label.text = newText;
    size.y = label.height > sizeY ? label.height : sizeY;
  }
}

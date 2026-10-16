import 'dart:ui' as ui;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/mario_translation/bullet.dart';
import 'package:life_pilot/game/mario_translation/controller_game_mario_translation.dart';
import 'package:life_pilot/game/mario_translation/enemy.dart';
import 'package:life_pilot/game/mario_translation/mario_text_component.dart';
import 'package:life_pilot/game/mario_translation/model_game_mario_translation.dart';
import 'package:life_pilot/game/mario_translation/page_game_mario_translation.dart';
import 'package:life_pilot/game/mario_translation/player.dart';
import 'package:life_pilot/game/mario_translation/question_display.dart';

late ui.Image _spriteImage;

class _Controller implements ControllerGameMarioTranslation {
  @override
  ModelGameMarioTranslation? currentQuestion;
  @override
  int score = 0;
  @override
  bool isFinished = false;
  @override
  Future<void> speak(String text) async {}
  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Use real game/collision/option code, with only assets and external services stubbed.
class _Player extends Player {
  _Player() : super(position: Vector2(50, 450), size: Vector2.all(50));
  @override
  Future<void> onLoad() async {
    sprite = Sprite(_spriteImage);
    add(RectangleHitbox());
  }
}

class _Enemy extends Enemy {
  _Enemy(VoidCallback onStomp)
    : super(
        onStomp: onStomp,
        position: Vector2(130, 450),
        size: Vector2.all(50),
      );
  @override
  Future<void> onLoad() async {
    sprite = Sprite(_spriteImage);
    add(RectangleHitbox());
  }
}

class _Game extends PageGameMarioTranslation {
  final List<String> options;
  _Game(this.options)
    : super(
        gameId: 'test',
        gameLevel: 1,
        userName: 'test',
        scoreLabel: 'Score',
        questionLabel: 'Question',
        onFinished: _noop,
      );
  @override
  Future<void> onLoad() async {
    screenW = 800;
    screenH = 600;
    sizeX = 50;
    sizeY = 100;
    controller = _Controller()
      ..currentQuestion = ModelGameMarioTranslation(
        questionId: 'q',
        question: 'Question',
        options: options,
        correctAnswer: options.first,
      );
    ground = RectangleComponent(
      position: Vector2(0, 500),
      size: Vector2(800, 50),
    );
    player = _Player();
    questionText = QuestionDisplay(
      text: 'Question',
      controller: controller,
      positionX: 40,
      positionY: 100,
      sizeX: 300,
      sizeY: 50,
    );
    scoreText = QuestionDisplay(
      text: 'Score',
      controller: controller,
      positionX: 40,
      positionY: 50,
      sizeX: 300,
      sizeY: 50,
    );
    addAll([ground, player, questionText, scoreText]);
  }

  @override
  void spawnEnemy() {
    if (children.whereType<Enemy>().isEmpty) add(_Enemy(spawnOptions));
  }
}

void _noop() {}

Future<void> _mountGame(WidgetTester tester, _Game game) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: GameWidget(game: game),
    ),
  );
  await tester.runAsync(() async {
    await game.toBeLoaded();
    await game.ready();
  });
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint());
    final picture = recorder.endRecording();
    _spriteImage = await picture.toImage(1, 1);
    picture.dispose();
  });
  tearDownAll(() => _spriteImage.dispose());
  const style = TextStyle(fontSize: 24);
  for (final text in [
    'This answer contains several English words that need wrapping',
    'SupercalifragilisticexpialidociousWithoutAnySpaces',
    '第一個答案需要正常換行並且可以繼續玩遊戲',
    '日本語の選択肢を複数行で表示します',
    '한국어 선택지를 여러 줄로 표시합니다',
    'Line one\n\nLine three 👨‍👩‍👧‍👦 😀',
  ]) {
    test('safe text layout completes for $text', () {
      final label = MarioTextComponent(text: text, maxWidth: 80, style: style);
      expect(label.width, 80);
      expect(label.height, isPositive);
      expect(label.height.isFinite, true);
      expect(label.text, text);
      label.onRemove();
    });
  }
  test('narrow and empty text can update and remount', () {
    final label = MarioTextComponent(
      text: '',
      maxWidth: 1,
      style: style,
      padding: const EdgeInsets.all(8),
    );
    label.text = 'Long word';
    expect(label.height.isFinite, true);
    label.onRemove();
    label.onMount();
    label.text = 'New';
    expect(label.text, 'New');
    label.onRemove();
  });
  test('invalid width is rejected before layout', () {
    for (final width in [0.0, -1.0, double.infinity, double.nan]) {
      expect(
        () => MarioTextComponent(text: 'test', maxWidth: width, style: style),
        throwsArgumentError,
      );
    }
  });
  for (final options in [
    [
      'This is a long English answer that wraps onto multiple lines',
      'Another answer',
      'Third answer',
    ],
    ['很長的中文答案需要自動換行', '答案二', '答案三'],
    ['日本語の長い選択肢を表示するテスト', '選択肢二', '選択肢三'],
    ['한국어 긴 선택지를 표시하는 테스트', '두 번째', '세 번째'],
  ]) {
    testWidgets(
      'first bullet hit loads options and updates continue: ${options.first}',
      (tester) async {
        final game = _Game(options);
        await _mountGame(tester, game);
        final enemy = game.children.whereType<Enemy>().single;
        enemy.position.setValues(
          game.player.position.x + 100,
          game.player.position.y,
        );
        enemy.velocity = Vector2.zero();
        await game.shoot();
        await tester.runAsync(game.ready);
        for (var i = 0; i < 8; i++) {
          game.update(0.05);
        }
        await tester.runAsync(game.ready);
        expect(game.optionItems.length, 3);
        expect(game.children.whereType<Enemy>(), isEmpty);
        expect(game.children.whereType<Bullet>(), isEmpty);
        final item = game.optionItems.first;
        expect(
          item.children.whereType<MarioTextComponent>().single.text,
          options.first,
        );
        expect(item.height, greaterThanOrEqualTo(50));
        final y = item.position.y;
        game.update(0.1);
        expect(item.position.y, greaterThan(y));
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('one bullet cannot remove multiple answer cards', (tester) async {
    final game = _Game(['one', 'two', 'three']);
    await _mountGame(tester, game);
    game.spawnOptions();
    await tester.runAsync(game.ready);
    final first = game.optionItems[0];
    final second = game.optionItems[1];
    final bullet = Bullet(position: Vector2.zero(), direction: Vector2(1, 0));
    bullet.onCollision({}, first);
    bullet.onCollision({}, second);
    expect(first.isRemovedQ, true);
    expect(second.isRemovedQ, false);
    expect(game.optionItems.length, 2);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'question update before load is retained and no physics hitbox is added',
    (tester) async {
      final game = _Game(['one', 'two', 'three']);
      await _mountGame(tester, game);
      final display = QuestionDisplay(
        text: 'old',
        controller: game.controller,
        positionX: 0,
        positionY: 0,
        sizeX: 100,
        sizeY: 50,
      );
      display.updateText('A new question that wraps');
      game.add(display);
      await tester.runAsync(game.ready);
      expect(
        display.children.whereType<MarioTextComponent>().single.text,
        'A new question that wraps',
      );
      expect(display.children.whereType<RectangleHitbox>(), isEmpty);
      display.updateText('next');
      expect(
        display.children.whereType<MarioTextComponent>().single.text,
        'next',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}

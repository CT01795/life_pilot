import 'dart:math';

import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/game/controller_game_steam_super_hero.dart';

class WidgetsGameSteamSuperHeroGameBoard extends StatelessWidget {
  final ControllerGameSteamSuperHero game;

  const WidgetsGameSteamSuperHeroGameBoard({super.key, required this.game});

  // 隨機水果 icon
  static final List<IconData> fruitIcons = [
    Icons.apple_rounded,
    Icons.card_giftcard_rounded,
    Icons.favorite_rounded,
    Icons.star_rounded,
    Icons.diamond_rounded,
    Icons.cake_rounded
  ];

  static IconData getRandomFruitIconStatic() {
    final rand = Random();
    return fruitIcons[rand.nextInt(fruitIcons.length)];
  }

  @override
  Widget build(BuildContext context) {
    final size = 40.0;
    // ---- 正確計算場景最大 X, Y ----
    final allPoints = [
      ...game.level.obstacles
          .map((o) => Offset(o.x.toDouble(), o.y.toDouble())),
      ...game.level.fruits.map((f) => Offset(f.x.toDouble(), f.y.toDouble())),
      Offset(
          game.level.treasure.x.toDouble(), game.level.treasure.y.toDouble()),
      Offset(game.state.x.toDouble(), game.state.y.toDouble()),
    ];

    final maxX = allPoints.map((e) => e.dx).reduce(max).toInt() + 2;
    final maxY = allPoints.map((e) => e.dy).reduce(max).toInt() + 2;
    return Stack(
      children: [
        // --------------------------
        // 背景格子（柔和綠 & Good looking）
        // --------------------------
        for (int i = 0; i < maxX; i++)
          for (int j = 0; j < maxY; j++)
            Positioned(
              left: i * size,
              bottom: j * size,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: (i + j) % 2 == 0
                      ? Colors.green.shade200
                      : Colors.green.shade100,
                ),
              ),
            ),

        // --------------------------
        // 障礙物（深木頭風格）
        // --------------------------
        ...game.level.obstacles.map((o) => Positioned(
              left: o.x * size,
              bottom: o.y * size,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.brown.shade500,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 3,
                        offset: Offset(2, 2))
                  ],
                ),
              ),
            )),

        // --------------------------
        // 水果（隨機一次，不會閃動）
        // --------------------------
        ...game.level.fruits.map((f) => Positioned(
              left: f.x * size,
              bottom: f.y * size,
              child: Icon(
                f.collected ? Icons.circle_outlined : f.icon,
                color: f.collected ? Colors.transparent : Colors.pink.shade400,
                size: size,
              ),
            )),
        // --------------------------
        // 角色（主題色）
        // --------------------------
        Positioned(
          left: game.state.x * size,
          bottom: game.state.y * size,
          child: Icon(Icons.directions_walk_rounded,
              color: Colors.indigo.shade600, size: size),
        ),
        // --------------------------
        // 寶藏（金色 + 陰影）
        // --------------------------
        Positioned(
          left: game.level.treasure.x * size,
          bottom: game.level.treasure.y * size,
          child: Icon(
            Icons.vpn_key_rounded,
            size: size,
            color: Colors.amber.shade700,
            shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
          ),
        ),
        // -------------------------- 分數 Overlay --------------------------
        Positioned(
          top: 2,
          left: 16,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ValueListenableBuilder<GameState>(
              valueListenable: game.stateNotifier,
              builder: (context, state, _) {
                return Text(
                  'Score: ${state.score}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

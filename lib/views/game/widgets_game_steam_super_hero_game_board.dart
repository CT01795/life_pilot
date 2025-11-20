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

  IconData getRandomFruitIcon() {
    final rand = Random();
    return fruitIcons[rand.nextInt(fruitIcons.length)];
  }

  @override
  Widget build(BuildContext context) {
    // ---- 正確計算場景最大 X, Y ----
    final allPoints = [
      ...game.level.obstacles.map((o) => Offset(o.x.toDouble(), o.y.toDouble())),
      ...game.level.fruits.map((f) => Offset(f.x.toDouble(), f.y.toDouble())),
      Offset(game.level.treasure.x.toDouble(), game.level.treasure.y.toDouble()),
      Offset(game.x.toDouble(), game.y.toDouble()),
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
              left: i * 50.0,
              bottom: j * 50.0,
              child: Container(
                width: 50,
                height: 50,
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
              left: o.x * 50.0,
              bottom: o.y * 50.0,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.brown.shade500,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26, blurRadius: 3, offset: Offset(2, 2))
                  ],
                ),
              ),
            )),

        // --------------------------
        // 水果（隨機一次，不會閃動）
        // --------------------------
        ...game.level.fruits.map((f) => Positioned(
              left: f.x * 50.0,
              bottom: f.y * 50.0,
              child: Icon(
                f.collected ? Icons.circle_outlined : getRandomFruitIcon(),
                color: f.collected ? Colors.transparent : Colors.pink.shade400,
                size: 40,
              ),
            )),
        // --------------------------
        // 角色（主題色）
        // --------------------------
        Positioned(
          left: game.x * 50.0,
          bottom: game.y * 50.0,
          child:
              Icon(Icons.directions_walk_rounded, color: Colors.indigo.shade600, size: 40),
        ),
        // --------------------------
        // 寶藏（金色 + 陰影）
        // --------------------------
        Positioned(
          left: game.level.treasure.x * 50.0,
          bottom: game.level.treasure.y * 50.0,
          child: Icon(Icons.vpn_key_rounded, size: 50, color: Colors.amber.shade700,
            shadows: [Shadow(blurRadius: 4, color: Colors.black26)],),
        ),
      ],
    );
  }
}

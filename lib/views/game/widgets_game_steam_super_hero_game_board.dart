import 'dart:math';

import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/game/controller_game_steam_super_hero.dart';

class WidgetsGameSteamSuperHeroGameBoard extends StatelessWidget {
  final ControllerGameSteamSuperHero game;
  final double tileSize;

  const WidgetsGameSteamSuperHeroGameBoard({super.key, required this.game, required this.tileSize,});

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
    // --------------------------
    // 計算整個地圖最大 x/y
    // --------------------------
    final maxX = game.level.treasure.x.toInt();
    final maxY = game.level.treasure.y.toInt();
    
    return Stack(
      children: [
        // --------------------------
        // 背景格子（柔和綠 & Good looking）
        // --------------------------
        for (int i = 0; i <= maxX; i++)
          for (int j = 0; j <= maxY; j++)
            Positioned(
              left: i * tileSize,
              bottom: j * tileSize,
              child: Container(
                width: tileSize,
                height: tileSize,
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
              left: o.x * tileSize,
              bottom: o.y * tileSize,
              child: Container(
                width: tileSize,
                height: tileSize,
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
              left: f.x * tileSize,
              bottom: f.y * tileSize,
              child: Icon(
                f.collected ? Icons.circle_outlined : f.icon,
                color: f.collected ? Colors.transparent : Colors.pink.shade400,
                size: tileSize,
              ),
            )),
        // --------------------------
        // 角色（主題色）
        // --------------------------
        Positioned(
          left: game.state.x * tileSize,
          bottom: game.state.y * tileSize,
          child: Icon(Icons.directions_walk_rounded,
              color: Colors.indigo.shade600, size: tileSize),
        ),
        // --------------------------
        // 寶藏（金色 + 陰影）
        // --------------------------
        Positioned(
          left: game.level.treasure.x * tileSize,
          bottom: game.level.treasure.y * tileSize,
          child: Icon(
            Icons.vpn_key_rounded,
            size: tileSize,
            color: Colors.amber.shade700,
            shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
          ),
        ),
      ],
    );
  }
}

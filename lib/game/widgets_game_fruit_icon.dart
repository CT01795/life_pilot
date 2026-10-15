import 'package:flutter/material.dart';
import 'package:life_pilot/game/model_game_fruit_appearance.dart';

IconData gameFruitIcon(EnumScratchFruitAppearance appearance) =>
    switch (appearance) {
      EnumScratchFruitAppearance.apple => Icons.apple_rounded,
      EnumScratchFruitAppearance.gift => Icons.card_giftcard_rounded,
      EnumScratchFruitAppearance.heart => Icons.favorite_rounded,
      EnumScratchFruitAppearance.star => Icons.star_rounded,
      EnumScratchFruitAppearance.diamond => Icons.diamond_rounded,
      EnumScratchFruitAppearance.cake => Icons.cake_rounded,
    };

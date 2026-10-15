import 'dart:math';

enum EnumScratchFruitAppearance { apple, gift, heart, star, diamond, cake }

final Random _fruitRandom = Random();

EnumScratchFruitAppearance randomGameFruitAppearance() =>
    EnumScratchFruitAppearance.values[_fruitRandom.nextInt(
      EnumScratchFruitAppearance.values.length,
    )];

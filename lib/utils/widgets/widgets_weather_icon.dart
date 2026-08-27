import 'package:flutter/material.dart';

class WidgetsWeatherIcon extends StatelessWidget {
  final String icon;
  final double size;

  const WidgetsWeatherIcon({
    super.key,
    required this.icon,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/weather_icons/$icon.png',
      width: size,
      height: size,
      errorBuilder: (_, __, ___) => Image.network(
        'https://openweathermap.org/img/wn/$icon.png',
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => SizedBox.square(dimension: size),
      ),
    );
  }
}

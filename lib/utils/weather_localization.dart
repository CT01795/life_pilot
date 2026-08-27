import 'package:life_pilot/l10n/app_localizations.dart';

String localizeWeatherCondition(
  AppLocalizations loc,
  String condition,
) {
  return switch (condition.toLowerCase()) {
    'thunderstorm' => loc.weatherThunderstorm,
    'drizzle' => loc.weatherDrizzle,
    'rain' => loc.weatherRain,
    'snow' => loc.weatherSnow,
    'mist' ||
    'smoke' ||
    'haze' ||
    'dust' ||
    'fog' ||
    'sand' ||
    'ash' ||
    'squall' ||
    'tornado' =>
      loc.weatherMist,
    'clear' => loc.weatherClear,
    'clouds' => loc.weatherClouds,
    _ => condition,
  };
}

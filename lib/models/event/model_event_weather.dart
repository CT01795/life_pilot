class EventWeather {
  final DateTime date;
  final String main;       // 天氣主描述 e.g., Rain, Clear
  final String description; // 詳細描述 e.g., light rain
  final double temp;       // 溫度 (Kelvin)
  final double feelsLike; // 體感溫度
  final double tempMin; // 最低溫
  final double tempMax; // 最高溫
  final double pressure; // 氣壓
  final double seaLevel; // 
  final double grndLevel; // 
  final String icon;       // OpenWeather 圖標代碼

  EventWeather({
    required this.date,
    required this.main,
    required this.description,
    required this.icon,
    required this.temp,
    required this.feelsLike, // 體感溫度
    required this.tempMin, // 最低溫
    required this.tempMax, // 最高溫
    required this.pressure, // 氣壓
    required this.seaLevel, // 
    required this.grndLevel, // 
  });

  factory EventWeather.fromJson(Map<String, dynamic> json) {
    return EventWeather(
      date: DateTime.parse(json['date']),
      main: json['main'],
      description: json['description'],
      icon: json['icon'],
      temp: (json['temp'] as num).toDouble(),
      feelsLike: (json['feels_like'] as num).toDouble(),
      tempMin: (json['temp_min'] as num).toDouble(),
      tempMax: (json['temp_max'] as num).toDouble(),
      pressure: (json['pressure'] as num).toDouble(),
      seaLevel: (json['sea_level'] as num).toDouble(),
      grndLevel: (json['grnd_level'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'main': main,
        'description': description,
        'icon': icon,
        'temp': temp,
        'feels_like': feelsLike,
        'temp_min': tempMin,
        'temp_max': tempMax,
        'pressure': pressure,
        'sea_level': seaLevel,
        'grnd_level': grndLevel,
      };
}

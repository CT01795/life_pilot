class EventWeather {
  final String main;       // 天氣主描述 e.g., Rain, Clear
  final String description; // 詳細描述 e.g., light rain
  final double temp;       // 溫度 (Kelvin)
  final String icon;       // OpenWeather 圖標代碼

  EventWeather({
    required this.main,
    required this.description,
    required this.temp,
    required this.icon,
  });

  factory EventWeather.fromJson(Map<String, dynamic> json) {
    final weatherData = json['weather'][0];
    final mainData = json['main'];
    return EventWeather(
      main: weatherData['main'],
      description: weatherData['description'],
      temp: mainData['temp'].toDouble(),
      icon: weatherData['icon'],
    );
  }
}

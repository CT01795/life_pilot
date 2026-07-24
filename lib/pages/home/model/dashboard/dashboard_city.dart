class DashboardCity {
  final String name;
  final int count;
  DashboardCity({
    required this.name,
    required this.count,
  });

  factory DashboardCity.fromJson(
    Map<String, dynamic> json,
  ) {
    return DashboardCity(
      name: json['city'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

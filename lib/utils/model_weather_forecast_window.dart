/// Calendar-date eligibility only; no service, widget, cache or account state.
class ModelWeatherForecastWindow {
  final DateTime today;
  final DateTime endExclusive;

  const ModelWeatherForecastWindow._(this.today, this.endExclusive);

  factory ModelWeatherForecastWindow(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return ModelWeatherForecastWindow._(
      today,
      today.add(const Duration(days: 7)),
    );
  }

  bool includes({required DateTime? startDate, required DateTime? endDate}) {
    if (startDate == null) return false;
    final end = endDate ?? startDate;
    final eventStart = DateTime(startDate.year, startDate.month, startDate.day);
    final eventEnd = DateTime(end.year, end.month, end.day);
    return eventStart.isBefore(endExclusive) && !eventEnd.isBefore(today);
  }
}

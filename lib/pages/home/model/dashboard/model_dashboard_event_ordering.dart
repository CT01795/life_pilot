/// Shared dashboard ordering, without widgets, localization or account state.
/// The schedule/recommendation adapters prepare one key per decoded event.
class DashboardEventOrderKey implements Comparable<DashboardEventOrderKey> {
  static final _undated = DateTime(9999);
  final DateTime date;
  final int minutes;
  final String city, location, name;

  DashboardEventOrderKey({
    required DateTime? date,
    required this.minutes,
    required String? city,
    required String? location,
    required this.name,
  }) : date = date ?? _undated,
       city = city ?? '',
       location = location ?? '';

  @override
  int compareTo(DashboardEventOrderKey other) {
    var order = date.compareTo(other.date);
    if (order != 0) return order;
    order = minutes.compareTo(other.minutes);
    if (order != 0) return order;
    order = city.compareTo(other.city);
    if (order != 0) return order;
    order = location.compareTo(other.location);
    return order != 0 ? order : name.compareTo(other.name);
  }
}

class ModelDashboardEventOrdering {
  static List<T> sorted<T>(
    Iterable<T> events, {
    required DashboardEventOrderKey Function(T) keyOf,
  }) {
    final keyed = [
      for (final event in events) (event: event, key: keyOf(event)),
    ];
    keyed.sort((a, b) => a.key.compareTo(b.key));
    return [for (final entry in keyed) entry.event];
  }
}

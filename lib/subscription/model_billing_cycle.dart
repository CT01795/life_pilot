enum BillingCycle {
  month(1),
  quarter(3);

  const BillingCycle(this.months);
  final int months;

  static BillingCycle from(Object? value) => switch (value) {
    null || 'month' => month,
    'quarter' => quarter,
    _ => throw FormatException('Unknown billing cycle: $value'),
  };

  /// Calendar months, clamped to the destination month's last day (not 30/90 days).
  DateTime endFrom(DateTime start) {
    final first = DateTime(start.year, start.month + months);
    final lastDay = DateTime(first.year, first.month + 1, 0).day;
    final day = start.day > lastDay ? lastDay : start.day;
    return start.isUtc
        ? DateTime.utc(
            first.year,
            first.month,
            day,
            start.hour,
            start.minute,
            start.second,
            start.millisecond,
            start.microsecond,
          )
        : DateTime(
            first.year,
            first.month,
            day,
            start.hour,
            start.minute,
            start.second,
            start.millisecond,
            start.microsecond,
          );
  }
}

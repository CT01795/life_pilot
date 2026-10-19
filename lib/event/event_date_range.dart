/// Date-only validation: time-of-day is handled separately by the form.
bool eventEndBeforeStart(DateTime? start, DateTime? end) =>
    start != null &&
    end != null &&
    DateTime(
      end.year,
      end.month,
      end.day,
    ).isBefore(DateTime(start.year, start.month, start.day));

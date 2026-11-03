import 'package:life_pilot/event/event_deduplication_key.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads only deduplication fields for the calendar days in the import batch.
class RepositoryImportDeletionKeys {
  RepositoryImportDeletionKeys(this.client);
  final SupabaseClient client;
  final _loadedExistingDays = <DateTime>{};

  Future<Set<String>> read(Iterable<DateTime> dates) =>
      _read(TableNames.recommendEventsDeleted, dates);

  Future<Set<String>> readExisting(Iterable<DateTime> dates) =>
      _read(TableNames.recommendEvents, dates);

  /// Only for a single refresh. The caller retains the returned keys across sources.
  Future<Set<String>> readNewExistingDays(Iterable<DateTime> dates) async {
    final days = _calendarDays(dates).difference(_loadedExistingDays);
    final keys = await readExisting(days);
    _loadedExistingDays.addAll(days);
    return keys;
  }

  Set<DateTime> _calendarDays(Iterable<DateTime> dates) =>
      dates.map((date) => DateTime(date.year, date.month, date.day)).toSet();

  Future<Set<String>> _read(String table, Iterable<DateTime> dates) async {
    final days = _calendarDays(dates).toList();
    final keys = <String>{};
    const dayBatch = 12;
    const pageSize = 300;
    for (var index = 0; index < days.length; index += dayBatch) {
      final clauses = days
          .skip(index)
          .take(dayBatch)
          .map((day) {
            final next = DateTime(day.year, day.month, day.day + 1);
            return 'and(start_date.gte.${day.toUtc().toIso8601String()},'
                'start_date.lt.${next.toUtc().toIso8601String()})';
          })
          .join(',');
      for (var offset = 0; ; offset += pageSize) {
        final rows = await client
            .from(table)
            .select('id,name,start_date,start_time,city,location')
            .or(clauses)
            .order('start_date')
            .order('id')
            .range(offset, offset + pageSize - 1);
        for (final row in rows) {
          final event = EventItem.fromJson(json: row);
          if (event.startDate == null) continue;
          event.startDate = event.startDate!.toLocal();
          keys.addAll([
            EventDeduplicationKey.byName(event),
            EventDeduplicationKey.byNameIgnoringTime(event),
            EventDeduplicationKey.byId(event),
          ]);
        }
        if (rows.length < pageSize) break;
      }
    }
    return keys;
  }
}

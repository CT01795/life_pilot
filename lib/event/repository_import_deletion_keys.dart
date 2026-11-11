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
    if (days.isEmpty) return {};
    final keys = <String>{};
    final rows =
        await client.rpc(
              'get_public_event_deduplication_rows',
              params: {
                'p_deleted': table == TableNames.recommendEventsDeleted,
                'p_dates': days
                    .map(
                      (day) =>
                          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
                    )
                    .toList(growable: false),
              },
            )
            as List;
    for (final row in rows) {
      final event = EventItem.fromJson(json: Map<String, dynamic>.from(row));
      if (event.startDate == null) continue;
      event.startDate = event.startDate!.toLocal();
      keys.addAll([
        EventDeduplicationKey.byName(event),
        EventDeduplicationKey.byNameIgnoringTime(event),
        EventDeduplicationKey.byId(event),
      ]);
    }
    return keys;
  }
}

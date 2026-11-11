import 'package:life_pilot/event/event_deduplication_key.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads only deduplication fields for the calendar days in the import batch.
class RepositoryImportDeletionKeys {
  RepositoryImportDeletionKeys(this.client);
  final SupabaseClient client;
  final _loadedDays = <DateTime>{};

  /// Reads active and deleted identities together. A refresh retains the
  /// returned keys, so each calendar day is fetched at most once.
  Future<Set<String>> readNewDays(Iterable<DateTime> dates) async {
    final days = _calendarDays(dates).difference(_loadedDays);
    final keys = await _read(days);
    _loadedDays.addAll(days);
    return keys;
  }

  Set<DateTime> _calendarDays(Iterable<DateTime> dates) =>
      dates.map((date) => DateTime(date.year, date.month, date.day)).toSet();

  Future<Set<String>> _read(Iterable<DateTime> dates) async {
    final days = _calendarDays(dates).toList();
    if (days.isEmpty) return {};
    final keys = <String>{};
    final rows =
        await client.rpc(
              'get_public_event_deduplication_rows_v2',
              params: {
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

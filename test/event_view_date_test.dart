import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/model_event_view_cache.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';
import 'package:life_pilot/l10n/app_localizations_ja.dart';
import 'package:life_pilot/l10n/app_localizations_ko.dart';
import 'package:life_pilot/l10n/app_localizations_zh.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/lazy_mapped_list.dart';

EventViewModel _view({DateTime? start, String text = ''}) => EventViewModel(
  event: EventItem(id: 'event', name: 'Event'),
  id: 'event',
  name: 'Event',
  showDate: true,
  startDate: start,
  endDate: null,
  dateRange: text,
  tags: [],
  hasLocation: false,
  locationDisplay: '',
);

void main() {
  test('real date takes precedence over stale or malformed display text', () {
    for (final text in ['', 'invalid', '2001/01/01', '1/2 19:00 - 20:00']) {
      final view = _view(start: DateTime(2027, 12, 31, 23, 59), text: text);
      final first = view.firstEventDate;
      expect(first, DateTime(2027, 12, 31));
      expect(view.firstEventDate, same(first));
    }
  });

  test('legacy views without raw dates retain explicit-year parsing', () {
    expect(
      _view(text: '2025/12/31 19:00 - 20:00').firstEventDate,
      DateTime(2025, 12, 31),
    );
  });

  test('legacy views retain current-year parsing and undated fallback', () {
    final now = DateTime.now();
    expect(_view(text: '1/2 19:00').firstEventDate, DateTime(now.year, 1, 2));
    expect(
      _view(text: '').firstEventDate,
      DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
    );
  });

  test('all card tables and locales use raw year and date', () {
    final locales = <AppLocalizations>[
      AppLocalizationsZh(),
      AppLocalizationsEn(),
      AppLocalizationsJa(),
      AppLocalizationsKo(),
    ];
    for (final table in [
      TableNames.calendarEvents,
      TableNames.memoryTrace,
      TableNames.recommendEvents,
      TableNames.recommendPlaces,
    ]) {
      for (final locale in locales) {
        final event = EventItem(
          id: 'a',
          name: 'A',
          startDate: DateTime(2027, 1, 2, 19),
        );
        final view = EventViewModel.buildEventViewModel(
          event: event,
          parentLocation: '',
          canDelete: false,
          loc: locale,
          tableName: table,
        );
        expect(view.firstEventDate, DateTime(2027, 1, 2));
      }
    }
  });

  test('date lookup never decodes deferred child records', () {
    var reads = 0;
    final event = EventItem(
      id: 'a',
      name: 'A',
      startDate: DateTime(2026, 10, 21),
    );
    event.subEvents = DeferredList([
      () {
        reads++;
        return EventItem(id: 'child', name: 'Child');
      },
    ]);
    final view = EventViewModel.buildEventViewModel(
      event: event,
      parentLocation: '',
      canDelete: false,
      loc: AppLocalizationsEn(),
      tableName: TableNames.memoryTrace,
    );
    for (var i = 0; i < 20; i++) {
      expect(view.firstEventDate, DateTime(2026, 10, 21));
    }
    expect(reads, 0);
    expect(view.subEvents.length, 1);
  });

  test('date edits refresh the cached view without changing old snapshots', () {
    final cache = ModelEventViewCache();
    final event = EventItem(
      id: 'a',
      name: 'A',
      startDate: DateTime(2026, 10, 21),
    );
    final loc = AppLocalizationsEn();
    EventViewModel build() => cache.build(
      event: event,
      loc: loc,
      tableName: TableNames.memoryTrace,
      canDelete: false,
    );
    final first = build();
    expect(first.firstEventDate, DateTime(2026, 10, 21));
    event.startDate = DateTime(2027, 1, 2);
    cache.invalidate(event.id);
    final updated = build();
    expect(updated.firstEventDate, DateTime(2027, 1, 2));
    expect(first.firstEventDate, DateTime(2026, 10, 21));
  });
}

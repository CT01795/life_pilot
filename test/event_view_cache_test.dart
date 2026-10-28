import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/model_event_view_cache.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';
import 'package:life_pilot/l10n/app_localizations_zh.dart';
import 'package:life_pilot/utils/const.dart';

class _Child extends EventItem {
  _Child() : super(id: 'child', name: 'child', description: 'child text');
  int reads = 0;
  @override
  String get description {
    reads++;
    return super.description;
  }
}

class _ChangedLabels extends AppLocalizationsEn {
  _ChangedLabels({this.changedPay = false, this.changedIndoor = false});
  final bool changedPay;
  final bool changedIndoor;
  @override
  String get pay => changedPay ? 'changed-pay' : super.pay;
  @override
  String get indoor => changedIndoor ? 'changed-indoor' : super.indoor;
}

void main() {
  late ModelEventViewCache cache;
  late EventItem event;
  late AppLocalizations loc;
  setUp(() {
    cache = ModelEventViewCache();
    event = EventItem(id: 'e', name: 'before', isFree: true);
    loc = AppLocalizationsEn();
  });

  EventViewModel build({
    EventItem? row,
    AppLocalizations? language,
    String table = TableNames.recommendEvents,
    bool canDelete = false,
  }) => cache.build(
    event: row ?? event,
    loc: language ?? loc,
    tableName: table,
    canDelete: canDelete,
  );

  test('unchanged presentation inputs reuse the view model', () {
    final first = build();
    expect(identical(build(), first), isTrue);
  });

  test('equivalent localization instances reuse deferred child models', () {
    final child = _Child();
    event.subEvents = [child];
    final first = build();
    final childView = first.subEvents.single;
    final second = build(language: AppLocalizationsEn());
    expect(second, same(first));
    expect(second.subEvents.single, same(childView));
    expect(child.reads, 1);
  });

  test('changed pay label invalidates even when only a child uses it', () {
    event.subEvents = [EventItem(id: 'paid', name: 'paid', isFree: false)];
    final first = build();
    final updated = build(language: _ChangedLabels(changedPay: true));
    expect(updated, isNot(same(first)));
    expect(updated.subEvents.single.tags, contains('changed-pay'));
    expect(first.subEvents.single.tags, contains(loc.pay));
  });

  test('changed indoor label invalidates deferred children', () {
    event.subEvents = [EventItem(id: 'indoor', name: 'in', isOutdoor: false)];
    final first = build();
    final updated = build(language: _ChangedLabels(changedIndoor: true));
    expect(updated, isNot(same(first)));
    expect(updated.subEvents.single.tags, contains('changed-indoor'));
    expect(first.subEvents.single.tags, contains(loc.indoor));
  });

  test('same-ID replacement refreshes content', () {
    final first = build();
    final replacement = build(
      row: EventItem(id: 'e', name: 'after'),
    );
    expect(identical(replacement, first), isFalse);
    expect(replacement.name, 'after');
  });

  test('locale change rebuilds translated tags', () {
    final first = build();
    final chinese = AppLocalizationsZh();
    final updated = build(language: chinese);
    expect(identical(updated, first), isFalse);
    expect(updated.tags, contains(chinese.free));
    expect(first.tags, contains(loc.free));
  });

  test('table change refreshes date visibility', () {
    expect(build().showDate, isTrue);
    expect(build(table: TableNames.recommendPlaces).showDate, isFalse);
  });

  test('changed delete permission cannot reuse a stale enabled action', () {
    final enabled = build(canDelete: true);
    final disabled = build(canDelete: false);
    expect(identical(enabled, disabled), isFalse);
    expect(enabled.canDelete, isTrue);
    expect(disabled.canDelete, isFalse);
    expect(build(canDelete: true).canDelete, isTrue);
  });

  test('in-place edits invalidate only the requested ID', () {
    final other = EventItem(id: 'other', name: 'untouched');
    final first = build();
    final keep = build(row: other);
    event.name = 'after';
    cache.invalidate(event.id);
    expect(identical(build(), first), isFalse);
    expect(build().name, 'after');
    expect(identical(build(row: other), keep), isTrue);
  });

  test('full clear releases previously cached models', () {
    final first = build();
    cache.clear();
    expect(identical(build(), first), isFalse);
    cache.invalidate('missing');
  });

  test('progressive rows retain unchanged models and deferred children', () {
    final child = _Child();
    event.subEvents = [child];
    final first = build();
    final childView = first.subEvents.single;
    final other = EventItem(id: 'other', name: 'next');
    cache.retainEvents([event, other]);
    expect(build(), same(first));
    expect(build().subEvents.single, same(childView));
    expect(child.reads, 1);
  });

  test('retaining current rows evicts removed and same-ID replaced models', () {
    final first = build();
    final other = EventItem(id: 'other', name: 'removed');
    final removed = build(row: other);
    final replacement = EventItem(id: event.id, name: 'replacement');
    cache.retainEvents([replacement]);
    expect(build(row: replacement).name, 'replacement');
    expect(build(row: other), isNot(same(removed)));
    expect(build(), isNot(same(first)));
    cache.retainEvents([]);
    final afterClear = build();
    expect(afterClear, isNot(same(first)));
  });

  test('cache hits preserve deferred children and their built models', () {
    final child = _Child();
    event.subEvents = [child];
    final first = build();
    expect(child.reads, 0);
    final childView = first.subEvents.single;
    expect(child.reads, 1);
    expect(identical(build().subEvents.single, childView), isTrue);
    expect(child.reads, 1);
  });
}

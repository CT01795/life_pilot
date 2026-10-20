import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';
import 'package:life_pilot/l10n/app_localizations_zh.dart';

class _Event extends EventItem {
  int reads = 0;
  _Event(String id, String text) : super(id: id, name: id, description: text);
  @override
  String get description {
    reads++;
    return super.description;
  }
}

void main() {
  final loc = AppLocalizationsEn();
  late ModelEvent model;
  setUp(() => model = ModelEvent());

  test('preview, extension and final snapshot index unchanged rows once', () {
    final first = _Event('first', 'needle');
    final next = _Event('next', 'needle');
    model
      ..setProgressiveEvents([first])
      ..updateSearchKeywords('needle');
    expect(model.getFilteredEvents(loc), [first]);
    model.setProgressiveEvents([first, next]);
    expect(model.getFilteredEvents(loc), [first, next]);
    model.setProgressiveEvents([first, next]);
    expect(model.getFilteredEvents(loc), [first, next]);
    expect([first.reads, next.reads], [1, 1]);
  });

  test('new same-ID instance replaces searchable text', () {
    final first = _Event('same', 'before');
    final replacement = _Event('same', 'after');
    model
      ..setProgressiveEvents([first])
      ..updateSearchKeywords('before');
    expect(model.getFilteredEvents(loc), [first]);
    model.setProgressiveEvents([replacement]);
    expect(model.getFilteredEvents(loc), isEmpty);
    model.updateSearchKeywords('after');
    expect(model.getFilteredEvents(loc), [replacement]);
  });

  test('explicit edit still invalidates retained parent and child text', () {
    final child = _Event('child', 'before');
    final parent = _Event('parent', 'other')..subEvents = [child];
    model
      ..setProgressiveEvents([parent])
      ..updateSearchKeywords('before');
    expect(model.getFilteredEvents(loc), [parent]);
    model.setProgressiveEvents([parent]);
    child.description = 'after';
    model.updateEvent(parent);
    expect(model.getFilteredEvents(loc), isEmpty);
    model.updateSearchKeywords('after');
    expect(model.getFilteredEvents(loc), [parent]);
  });

  test('normal full reload retains its conservative invalidation behavior', () {
    final first = _Event('first', 'before');
    model
      ..setProgressiveEvents([first])
      ..updateSearchKeywords('before');
    expect(model.getFilteredEvents(loc), [first]);
    first.description = 'after';
    model.setEvents([first]);
    expect(model.getFilteredEvents(loc), isEmpty);
    model.updateSearchKeywords('after');
    expect(model.getFilteredEvents(loc), [first]);
    expect(first.reads, 2);
  });

  test('language change refreshes retained localized labels', () {
    final first = _Event('first', '')..isFree = true;
    model
      ..setProgressiveEvents([first])
      ..updateSearchKeywords('free');
    expect(model.getFilteredEvents(loc), [first]);
    model.setProgressiveEvents([first]);
    final chinese = AppLocalizationsZh();
    expect(model.getFilteredEvents(chinese), isEmpty);
    model.updateSearchKeywords('免費');
    expect(model.getFilteredEvents(chinese), [first]);
  });

  test('scope reset releases old searchable records', () {
    final old = _Event('same', 'private');
    model
      ..setProgressiveEvents([old])
      ..updateSearchKeywords('private');
    expect(model.getFilteredEvents(loc), [old]);
    model.resetForDataScope();
    model
      ..setProgressiveEvents([_Event('same', 'other')])
      ..updateSearchKeywords('private');
    expect(model.getFilteredEvents(loc), isEmpty);
  });
}

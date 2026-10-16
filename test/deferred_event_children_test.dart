import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/lazy_mapped_list.dart';

void main() {
  test('first card and child count do not decode hidden children', () {
    var decoded = 0;
    final event = EventItem(id: 'parent', name: 'Parent');
    event.subEvents = DeferredList<EventItem>(
      List.generate(
        1000,
        (index) => () {
          decoded++;
          return EventItem(id: '$index', name: 'Child $index');
        },
      ),
    );
    final view = EventViewModel.buildEventViewModel(
      event: event,
      parentLocation: '',
      canDelete: false,
      loc: AppLocalizationsEn(),
      tableName: TableNames.memoryTrace,
    );
    expect(view.subEvents.length, 1000);
    expect(view.subEvents.isNotEmpty, true);
    expect(decoded, 0);
    expect(view.subEvents[0].name, 'Child 0');
    expect(decoded, 1);
    expect(event.subEvents[0].name, 'Child 0');
    expect(decoded, 1);
  });

  test('JSON children retain nested content during copy and serialization', () {
    final event = EventItem.fromJson(
      json: {
        'id': 'parent',
        'sub_events': [
          {
            'id': 'child',
            'name': 'Child',
            'start_time': '13:45',
            'sub_events': [
              {'id': 'grandchild', 'name': 'Grandchild'},
            ],
          },
        ],
      },
    );
    expect(event.subEvents, isA<DeferredList<EventItem>>());
    final copy = event.copyWith(newName: 'Copy');
    expect(copy.subEvents.single.startTime!.hour, 13);
    expect(copy.subEvents.single.subEvents.single.name, 'Grandchild');
    final restored = EventItem.fromJson(json: copy.toJson());
    expect(restored.subEvents.single.subEvents.single.id, 'grandchild');
    copy.subEvents.clear();
    expect(event.subEvents.length, 1);
  });

  test('deferred list supports the complete growable editing workflow', () {
    final list = DeferredList<int>([() => 3, () => 1, () => 2]);
    final snapshot = LazyMappedList(list, (int value) => '$value');
    list.add(4);
    list.addAll([5]);
    list.insert(0, 0);
    list.insertAll(1, [8, 9]);
    list[0] = 7;
    list.removeAt(1);
    list.removeRange(1, 2);
    list.sort();
    expect(list.toList(), [1, 2, 3, 4, 5, 7]);
    expect(snapshot.toList(), ['3', '1', '2']);
    list.length = 2;
    expect(list.toList(), [1, 2]);
    list.clear();
    list.add(10);
    expect(list.single, 10);
  });

  test('failed entry can retry and nullable values are cached', () {
    var attempts = 0;
    final list = DeferredList<String?>([
      () {
        if (++attempts == 1) throw StateError('retry');
        return null;
      },
    ]);
    expect(() => list.single, throwsStateError);
    expect(list.single, null);
    expect(list.single, null);
    expect(attempts, 2);
  });

  test('JSON text and malformed child payload retain parser behavior', () {
    final event = EventItem.fromJson(
      json: {
        'id': 'parent',
        'sub_events': '[{"id":"child","name":"Child"},null,3]',
      },
    );
    expect(event.subEvents.single.name, 'Child');
    expect(
      EventItem.fromJson(
        json: {'id': 'broken', 'sub_events': '[broken'},
      ).subEvents,
      isEmpty,
    );
  });
}

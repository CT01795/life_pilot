import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/model_event_projection.dart';

void main() {
  List<EventItem> rows() => [
    EventItem(id: 'one', name: 'One', account: 'one'),
    EventItem(id: 'two', name: 'Two', account: 'two'),
  ];
  test('stable inputs reuse owner-filtered list for loading notifications', () {
    final model = ModelEventProjection();
    final source = rows();
    var calls = 0;
    bool predicate(EventItem event) {
      calls++;
      return event.account == 'one';
    }

    final first = model.select(
      events: source,
      predicate: predicate,
      cacheKey: (true, 'one'),
    );
    final second = model.select(
      events: source,
      predicate: predicate,
      cacheKey: (true, 'one'),
    );
    expect(identical(first, second), true);
    expect(calls, 2);
    expect(first.single.id, 'one');
  });

  test('account, filter mode or source changes invalidate selection', () {
    final model = ModelEventProjection();
    final source = rows();
    final first = model.select(
      events: source,
      predicate: (e) => e.account == 'one',
      cacheKey: (true, 'one'),
    );
    final other = model.select(
      events: source,
      predicate: (e) => e.account == 'two',
      cacheKey: (true, 'two'),
    );
    expect(other.single.id, 'two');
    expect(identical(first, other), false);
    final updated = [EventItem(id: 'new', name: 'New', account: 'two')];
    expect(
      model
          .select(
            events: updated,
            predicate: (e) => e.account == 'two',
            cacheKey: (true, 'two'),
          )
          .single
          .id,
      'new',
    );
    expect(identical(model.select(events: source), source), true);
  });

  test('without an explicit key mutable predicates always run again', () {
    final model = ModelEventProjection();
    final source = rows();
    var account = 'one';
    bool predicate(EventItem event) => event.account == account;
    expect(model.select(events: source, predicate: predicate).single.id, 'one');
    account = 'two';
    expect(model.select(events: source, predicate: predicate).single.id, 'two');
  });

  test('changing only predicate key cannot reuse old results', () {
    final model = ModelEventProjection();
    final source = rows();
    var calls = 0;
    bool predicate(EventItem event) {
      calls++;
      return true;
    }

    model.select(
      events: source,
      predicate: predicate,
      cacheKey: (false, 'one'),
    );
    model.select(events: source, predicate: predicate, cacheKey: (true, 'one'));
    expect(calls, 4);
  });
}

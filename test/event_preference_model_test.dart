import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/model_event_preference.dart';

void main() {
  for (final like in <bool?>[null, false, true]) {
    for (final dislike in <bool?>[null, false, true]) {
      for (final action in EventPreferenceAction.values) {
        test('$like/$dislike $action matches the original transition', () {
          var expectedLike = like;
          var expectedDislike = dislike;
          if (action == EventPreferenceAction.like) {
            expectedLike = like == true ? false : true;
            expectedDislike = expectedLike == true ? false : dislike;
          } else {
            expectedDislike = dislike == true ? false : true;
            expectedLike = expectedDislike == true ? false : like;
          }
          final before = ModelEventPreference(isLike: like, isDislike: dislike);
          final after = before.toggle(action);
          expect(after.isLike, expectedLike);
          expect(after.isDislike, expectedDislike);
          expect(before.isLike, like);
          expect(before.isDislike, dislike);
        });
      }
    }
  }
  test('a saved snapshot restores nullable event state exactly', () {
    final event = EventItem(id: 'a', name: '', isLike: null, isDislike: null);
    final before = ModelEventPreference.fromEvent(event);
    before.toggle(EventPreferenceAction.like).applyTo(event);
    expect(event.isLike, isTrue);
    expect(event.isDislike, isFalse);
    before.applyTo(event);
    expect(event.isLike, isNull);
    expect(event.isDislike, isNull);
  });
  test('applying a snapshot does not change unrelated event fields', () {
    final event = EventItem(id: 'a', name: 'original', city: '台北');
    const ModelEventPreference(isLike: true, isDislike: false).applyTo(event);
    expect(event.id, 'a');
    expect(event.name, 'original');
    expect(event.city, '台北');
  });
}

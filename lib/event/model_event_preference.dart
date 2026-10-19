import 'package:life_pilot/event/model_event_item.dart';

enum EventPreferenceAction { like, dislike }

/// Preference transitions only. Persistence, sorting and notifications belong
/// to the service/controller; nullable legacy values remain unchanged unless
/// the selected action actually modifies them.
class ModelEventPreference {
  final bool? isLike;
  final bool? isDislike;

  const ModelEventPreference({required this.isLike, required this.isDislike});

  factory ModelEventPreference.fromEvent(EventItem event) =>
      ModelEventPreference(isLike: event.isLike, isDislike: event.isDislike);

  ModelEventPreference toggle(EventPreferenceAction action) {
    if (action == EventPreferenceAction.like) {
      final next = isLike != true;
      return ModelEventPreference(
        isLike: next,
        isDislike: next ? false : isDislike,
      );
    }
    final next = isDislike != true;
    return ModelEventPreference(isLike: next ? false : isLike, isDislike: next);
  }

  void applyTo(EventItem event) {
    event.isLike = isLike;
    event.isDislike = isDislike;
  }
}

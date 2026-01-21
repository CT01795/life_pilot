import 'package:flutter/material.dart' hide DateUtils;
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/models/event_rating/model_event_rating.dart';

class ControllerEventRatingCopy extends ChangeNotifier {
  final List<EventItem> _events = [];
  final Map<String, EventRating> _ratings = {};

  List<EventItem> get events => List.unmodifiable(_events);

  void addEvent(String name) {
    final newEvent = EventItem(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name);
    _events.add(newEvent);
    notifyListeners();
  }

  List<EventItem> searchEvents(String keyword) {
    return _events.where((e) => e.name.toLowerCase().contains(keyword.toLowerCase())).toList();
  }

  EventRating? getEventRating(String eventId) => _ratings[eventId];

  void submitEventRating(String eventId, int rating, [String comment = '']) {
    _ratings[eventId] = EventRating(id: eventId, rating: rating, comment: comment);
    notifyListeners();
  }
}

enum EventDeleteError { published, previouslyPublished }

class EventDeleteException implements Exception {
  const EventDeleteException(this.error);

  final EventDeleteError error;
}

enum EventDeleteError { reviewProtected }

class EventDeleteException implements Exception {
  const EventDeleteException(this.error);

  final EventDeleteError error;
}

enum EventSaveError { missingName, duplicate }

class EventSaveException implements Exception {
  const EventSaveException(this.error);

  final EventSaveError error;
}

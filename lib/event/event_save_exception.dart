enum EventSaveError { missingName, duplicate, permissionDenied }

class EventSaveException implements Exception {
  const EventSaveException(this.error);

  final EventSaveError error;
}

import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

/// Presentation-model cache only; request orchestration stays in Controller.
/// In-place event edits must invalidate their ID before the next build.
class ModelEventViewCache {
  final Map<String, _CachedEventView> _entries = {};

  EventViewModel build({
    required EventItem event,
    required AppLocalizations loc,
    required String tableName,
    required bool canDelete,
  }) {
    final cached = _entries[event.id];
    if (cached != null &&
        identical(cached.event, event) &&
        identical(cached.loc, loc) &&
        cached.tableName == tableName &&
        cached.canDelete == canDelete) {
      return cached.viewModel;
    }
    final viewModel = EventViewModel.buildEventViewModel(
      event: event,
      parentLocation: '',
      canDelete: canDelete,
      showSubEvents: true,
      loc: loc,
      tableName: tableName,
    );
    _entries[event.id] = _CachedEventView(
      event,
      loc,
      tableName,
      canDelete,
      viewModel,
    );
    return viewModel;
  }

  void invalidate(String eventId) => _entries.remove(eventId);

  /// Keep unchanged rows across progressive responses, releasing models for
  /// removed or replaced records. Locale/permission checks still happen in build.
  void retainEvents(Iterable<EventItem> events) {
    final current = {for (final event in events) event.id: event};
    _entries.removeWhere((id, cached) => !identical(current[id], cached.event));
  }

  void clear() => _entries.clear();
}

class _CachedEventView {
  final EventItem event;
  final AppLocalizations loc;
  final String tableName;
  final bool canDelete;
  final EventViewModel viewModel;

  const _CachedEventView(
    this.event,
    this.loc,
    this.tableName,
    this.canDelete,
    this.viewModel,
  );
}

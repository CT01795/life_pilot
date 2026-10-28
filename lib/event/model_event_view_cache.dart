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
    // Key the translated presentation by values, not the localization object's
    // lifetime. Include every label consumed by buildEventViewModel (children
    // included), so changed translations still invalidate deferred content.
    final labels = (
      locale: loc.localeName,
      free: loc.free,
      pay: loc.pay,
      outdoor: loc.outdoor,
      indoor: loc.indoor,
    );
    final cached = _entries[event.id];
    if (cached != null &&
        identical(cached.event, event) &&
        cached.labels == labels &&
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
      labels,
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
    if (_entries.isEmpty) return;
    // Visible-card caches are often much smaller than a loaded snapshot. Keep
    // only relevant IDs, but scan all rows: the LAST duplicate ID still wins.
    final current = <String, EventItem>{};
    for (final event in events) {
      final id = event.id;
      if (_entries.containsKey(id)) current[id] = event;
    }
    _entries.removeWhere((id, cached) => !identical(current[id], cached.event));
  }

  void clear() => _entries.clear();
}

class _CachedEventView {
  final EventItem event;
  final ({
    String locale,
    String free,
    String pay,
    String outdoor,
    String indoor,
  })
  labels;
  final String tableName;
  final bool canDelete;
  final EventViewModel viewModel;

  const _CachedEventView(
    this.event,
    this.labels,
    this.tableName,
    this.canDelete,
    this.viewModel,
  );
}

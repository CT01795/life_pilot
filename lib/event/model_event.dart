import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/model_event_ordering.dart';
import 'package:life_pilot/event/model_event_search_query.dart';
import 'package:life_pilot/event/model_event_search_index.dart';
import 'package:life_pilot/event/model_search_filter.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/date_time.dart';

class ModelEvent {
  List<EventItem> _events = [];
  bool isInitialized = false;
  bool _disposed = false;
  //--------------------------- event ---------------------------
  final _searchFilter = SearchFilter();
  SearchFilter get searchFilter => _searchFilter;
  bool showSearchPanel = false;
  final Set<String> selectedEventIds = {};
  final Set<String> removedEventIds = {};
  List<EventItem>? _filteredEventsCache;
  EventSearchLabels? _filteredEventsLabels;
  final _searchTextIndex = ModelEventSearchIndex();
  String? _parsedKeywords;
  ModelEventSearchQuery? _parsedQuery;
  (bool, DateTime)? _recommendedOrder;

  ModelEventSearchQuery _queryForCurrentKeywords() {
    final keywords = _searchFilter.keywords;
    if (_parsedQuery == null || _parsedKeywords != keywords) {
      _parsedKeywords = keywords;
      _parsedQuery = ModelEventSearchQuery(keywords);
    }
    return _parsedQuery!;
  }

  // Keep these aliases for existing callers; parsing belongs to the query.
  static final RegExp ageSingle = ModelEventSearchQuery.ageSingle;
  static final RegExp ageRange = ModelEventSearchQuery.ageRange;
  static final RegExp priceReg = ModelEventSearchQuery.price;

  List<EventItem> getFilteredEvents(AppLocalizations loc) {
    // The compatibility entry point extracts plain values; filtering and its
    // cache need neither a retained locale object nor its identity.
    final labels = (
      free: loc.free,
      pay: loc.pay,
      outdoor: loc.outdoor,
      indoor: loc.indoor,
    );
    if (_filteredEventsCache != null && _filteredEventsLabels == labels) {
      return _filteredEventsCache!;
    }
    _filteredEventsLabels = labels;
    return _filteredEventsCache = _filterEvents(
      events: _events,
      inFilter: _searchFilter,
      removedEventIds: removedEventIds,
      labels: labels,
    );
  }

  EventItem? findEventById(String id) {
    for (final event in _events) {
      if (event.id == id) return event;
    }
    return null;
  }

  void updateEvent(EventItem updatedEvent) {
    final index = _events.indexWhere((e) => e.id == updatedEvent.id);

    if (index != -1) {
      final previous = _events[index];
      _events[index] = updatedEvent;
      _recommendedOrder = null;
      _searchTextIndex.invalidate([previous, updatedEvent]);
      _invalidateFilteredEvents();
    }
  }

  void toggleSearchPanel(bool value, AppLocalizations loc) {
    showSearchPanel = value;
    /*if (!value) {
      clearSearchAll();
      getFilteredEvents(loc);
    }*/
  }

  void clearSearchAll() {
    _searchFilter.clear();
    _parsedKeywords = null;
    _parsedQuery = null;
    _invalidateFilteredEvents();
  }

  void updateSearchKeywords(String? keywords) {
    final next = keywords ?? '';
    final changed = _searchFilter.keywords != next;
    _searchFilter.keywords = next;
    // Tags are mutable presentation data: restore them even for equal input.
    _searchFilter.tags = List.of(_queryForCurrentKeywords().tokens);
    if (changed) _invalidateFilteredEvents();
  }

  void updateStartDate(DateTime? date) {
    final previous = (_searchFilter.startDate, _searchFilter.endDate);
    if (_searchFilter.endDate != null &&
        date != null &&
        date.isAfter(_searchFilter.endDate!)) {
      _searchFilter.endDate = date;
    }
    _searchFilter.startDate = date;
    if (previous != (_searchFilter.startDate, _searchFilter.endDate)) {
      _invalidateFilteredEvents();
    }
  }

  void updateEndDate(DateTime? date) {
    final previous = (_searchFilter.startDate, _searchFilter.endDate);
    if (_searchFilter.startDate != null &&
        date != null &&
        _searchFilter.startDate!.isAfter(date)) {
      _searchFilter.startDate = date;
    }
    _searchFilter.endDate = date;
    if (previous != (_searchFilter.startDate, _searchFilter.endDate)) {
      _invalidateFilteredEvents();
    }
  }

  void toggleEventSelection(String eventId, bool isSelected) {
    if (isSelected) {
      selectedEventIds.add(eventId);
    } else {
      selectedEventIds.remove(eventId);
    }
  }

  void markRemoved(String eventId) {
    removedEventIds.add(eventId);
    _invalidateFilteredEvents();
  }

  //--------------------------- calendar ---------------------------
  DateTime currentMonth = DateTimeFormatter.dateOnly(DateTime.now());

  // 標記 disposed
  void dispose() {
    _disposed = true;
  }

  bool get isDisposed => _disposed;

  //--------------------------- 核心方法 ---------------------------
  void removeEvent(EventItem event) {
    _recommendedOrder = null;
    final removed = <EventItem>[];
    _events.removeWhere((existing) {
      if (existing.id != event.id) return false;
      removed.add(existing);
      return true;
    });
    _searchTextIndex.invalidate(removed);
    _invalidateFilteredEvents();
  }

  void sortRecommendedContent({required bool isEvent, DateTime? now}) {
    final current = now ?? DateTime.now();
    ModelEventOrdering.sortRecommended(_events, isEvent: isEvent, now: current);
    _recommendedOrder = (
      isEvent,
      DateTime(current.year, current.month, current.day),
    );
    _invalidateFilteredEvents();
  }

  /// Preserve sorted/filter projections for unchanged pages on the same day.
  /// After midnight, ongoing activities still need their effective date updated.
  void appendRecommendedEvents(
    List<EventItem> list, {
    required bool isEvent,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final added = _appendUniqueEvents(list);
    final order = (isEvent, DateTime(current.year, current.month, current.day));
    if (!added && _recommendedOrder == order) return;
    sortRecommendedContent(isEvent: isEvent, now: current);
  }

  void clearAll() {
    _events.clear();
    _invalidateEventData();
  }

  void resetForDataScope() {
    _events.clear();
    selectedEventIds.clear();
    removedEventIds.clear();
    clearSearchAll();
    showSearchPanel = false;
    _invalidateEventData();
  }

  void setEvents(List<EventItem> list) =>
      _replaceEvents(list, preserveSearchIndex: false);

  /// A progressive service response retains unchanged object instances.
  /// Full reloads and in-place edits keep their explicit invalidation paths.
  void setProgressiveEvents(List<EventItem> list) =>
      _replaceEvents(list, preserveSearchIndex: true);

  void _replaceEvents(
    List<EventItem> list, {
    required bool preserveSearchIndex,
  }) {
    if (identical(_events, list)) {
      return;
    }
    _events = list;
    _recommendedOrder = null;
    if (preserveSearchIndex) {
      _searchTextIndex.retainEvents(list);
      _invalidateFilteredEvents();
    } else {
      _invalidateEventData();
    }
  }

  void appendMemoryEvents(List<EventItem> list) {
    if (!_appendUniqueEvents(list)) return;
    sortMemoryEvents();
  }

  void appendEvents(List<EventItem> list) {
    if (!_appendUniqueEvents(list)) return;
    _invalidateFilteredEvents();
  }

  /// Appending does not replace or mutate existing rows. Preserve their search
  /// indexes, including deferred child text; newly accepted objects are indexed
  /// on demand. Edits and full reloads retain their explicit invalidation paths.
  bool _appendUniqueEvents(List<EventItem> list) {
    if (list.isEmpty) return false;
    final existingIds = _events.map((event) => event.id).toSet();
    var added = false;
    for (final event in list) {
      if (!existingIds.add(event.id)) continue;
      _events.add(event);
      added = true;
    }
    if (added) _recommendedOrder = null;
    return added;
  }

  void sortMemoryEvents() {
    _recommendedOrder = null;
    ModelEventOrdering.sortMemory(_events);
    _invalidateFilteredEvents();
  }

  void _invalidateFilteredEvents() {
    _filteredEventsCache = null;
    _filteredEventsLabels = null;
  }

  void _invalidateEventData() {
    _recommendedOrder = null;
    _searchTextIndex.clear();
    _invalidateFilteredEvents();
  }

  List<EventItem> _filterEvents({
    required List<EventItem> events,
    required SearchFilter inFilter,
    required Set<String> removedEventIds,
    required EventSearchLabels labels,
  }) {
    final query = _queryForCurrentKeywords();

    if (query.isEmpty &&
        inFilter.startDate == null &&
        inFilter.endDate == null &&
        removedEventIds.isEmpty) {
      // ✅ 若沒有過濾條件，直接回傳原列表（避免無謂運算）
      return List<EventItem>.from(events);
    }
    return events.where((e) {
      if (removedEventIds.contains(e.id)) return false;
      if (!_matchesDateRange(e, inFilter)) return false;
      return query.matchesWithText(
        e,
        containsText: (word) =>
            _searchTextIndex.contains(e, word, labels: labels),
      );
    }).toList();
  }

  bool _matchesDateRange(EventItem event, SearchFilter filter) {
    if (filter.startDate == null && filter.endDate == null) return true;
    final rawStart = event.startDate;
    if (rawStart == null) return false;
    final start = DateTimeFormatter.dateOnly(rawStart);
    final end = DateTimeFormatter.dateOnly(event.endDate ?? rawStart);
    return (filter.startDate == null || !end.isBefore(filter.startDate!)) &&
        (filter.endDate == null || !start.isAfter(filter.endDate!));
  }
}

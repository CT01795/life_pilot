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
  AppLocalizations? _filteredEventsLoc;
  final _searchTextIndex = ModelEventSearchIndex();

  // Keep these aliases for existing callers; parsing belongs to the query.
  static final RegExp ageSingle = ModelEventSearchQuery.ageSingle;
  static final RegExp ageRange = ModelEventSearchQuery.ageRange;
  static final RegExp priceReg = ModelEventSearchQuery.price;

  List<EventItem> getFilteredEvents(AppLocalizations loc) {
    if (_filteredEventsCache != null && identical(_filteredEventsLoc, loc)) {
      return _filteredEventsCache!;
    }
    _filteredEventsLoc = loc;
    return _filteredEventsCache = _filterEvents(
      events: _events,
      inFilter: _searchFilter,
      removedEventIds: removedEventIds,
      loc: loc,
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
    _invalidateFilteredEvents();
  }

  void updateSearchKeywords(String? keywords) {
    _searchFilter.keywords = keywords ?? '';
    _invalidateFilteredEvents();
  }

  void updateStartDate(DateTime? date) {
    if (_searchFilter.endDate != null &&
        date != null &&
        date.isAfter(_searchFilter.endDate!)) {
      _searchFilter.endDate = date;
    }
    _searchFilter.startDate = date;
    _invalidateFilteredEvents();
  }

  void updateEndDate(DateTime? date) {
    if (_searchFilter.startDate != null &&
        date != null &&
        _searchFilter.startDate!.isAfter(date)) {
      _searchFilter.startDate = date;
    }
    _searchFilter.endDate = date;
    _invalidateFilteredEvents();
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
    ModelEventOrdering.sortRecommended(_events, isEvent: isEvent, now: now);
    _invalidateFilteredEvents();
  }

  void clearAll() {
    _events.clear();
    _invalidateEventData();
  }

  void resetForDataScope() {
    _events.clear();
    selectedEventIds.clear();
    removedEventIds.clear();
    _searchFilter.clear();
    showSearchPanel = false;
    _invalidateEventData();
  }

  void setEvents(List<EventItem> list) {
    if (identical(_events, list)) {
      return;
    }
    _events = list;
    _invalidateEventData();
  }

  void appendMemoryEvents(List<EventItem> list) {
    final existingIds = _events.map((event) => event.id).toSet();
    _events.addAll(list.where((event) => existingIds.add(event.id)));
    sortMemoryEvents();
  }

  void appendEvents(List<EventItem> list) {
    final existingIds = _events.map((event) => event.id).toSet();
    _events.addAll(list.where((event) => existingIds.add(event.id)));
    _invalidateEventData();
  }

  void sortMemoryEvents() {
    ModelEventOrdering.sortMemory(_events);
    _invalidateFilteredEvents();
  }

  void _invalidateFilteredEvents() {
    _filteredEventsCache = null;
    _filteredEventsLoc = null;
  }

  void _invalidateEventData() {
    _searchTextIndex.clear();
    _invalidateFilteredEvents();
  }

  List<EventItem> _filterEvents({
    required List<EventItem> events,
    required SearchFilter inFilter,
    required Set<String> removedEventIds,
    required AppLocalizations loc,
  }) {
    final query = ModelEventSearchQuery(inFilter.keywords);
    final labels = (
      free: loc.free,
      pay: loc.pay,
      outdoor: loc.outdoor,
      indoor: loc.indoor,
    );

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

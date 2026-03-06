import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/model_search_filter.dart';

class ModelEvent {
  List<EventItem> _events = [];
  bool isInitialized = false;
  bool _disposed = false;
  //--------------------------- event ---------------------------
  final searchFilter = SearchFilter();

  bool showSearchPanel = false;
  final Set<String> selectedEventIds = {};
  final Set<String> removedEventIds = {};

  static final RegExp ageSingle = RegExp(r'^(\d+)y$'); // 例如 "18y"
  static final RegExp ageRange = RegExp(r'^(\d+)y~(\d+)y$'); // 例如 "18y~25y"
  static final RegExp priceReg = RegExp(r'^\$?(\d+)(?:~\$?(\d+))?$');

  List<EventItem> getFilteredEvents(AppLocalizations loc) => _filterEvents(
      events: _events,
      filter: searchFilter,
      removedEventIds: removedEventIds,
      loc: loc);
  
  void updateEvent(EventItem updatedEvent) {
    final index = _events.indexWhere((e) => e.id == updatedEvent.id);

    if (index != -1) {
      _events[index] = updatedEvent;
    }
  }

  void toggleSearchPanel(bool value) {
    showSearchPanel = value;
    if (!value) clearSearchAll();
  }

  void clearSearchAll() {
    searchFilter.clear();
  }

  void updateSearchKeywords(String? keywords) {
    searchFilter.keywords = keywords ?? '';
  }

  void updateStartDate(DateTime? date) {
    if (searchFilter.endDate != null &&
        date != null &&
        date.isAfter(searchFilter.endDate!)) {
      searchFilter.endDate = date;
    }
    searchFilter.startDate = date;
  }

  void updateEndDate(DateTime? date) {
    if (searchFilter.startDate != null &&
        date != null &&
        searchFilter.startDate!.isAfter(date)) {
      searchFilter.startDate = date;
    }
    searchFilter.endDate = date;
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
    _events.removeWhere((e) => e.id == event.id);
  }

  void clearAll() {
    _events.clear();
  }

  void setEvents(List<EventItem> list) {
    _events = list;
  }
}

List<EventItem> _filterEvents({
  required List<EventItem> events,
  required SearchFilter filter,
  required Set<String> removedEventIds,
  required AppLocalizations loc,
}) {
  // 🧠 預先處理關鍵字（全部轉小寫）
  final List<String> keywords = filter.keywords
      .toLowerCase()
      .split(RegExp(r'[,，\s]+')) // ← 逗號（英文/中文）或任意空白都分隔 //.split(RegExp(r'\s+'))
      .map((s) => s.trim()) // 只修剪每個 tag 前後空白
      .where((word) => word.isNotEmpty)
      .toList();

  if (keywords.isEmpty && filter.startDate == null && removedEventIds.isEmpty) {
    // ✅ 若沒有過濾條件，直接回傳原列表（避免無謂運算）
    return List<EventItem>.from(events);
  }
  return events.where((e) {
    if (removedEventIds.contains(e.id)) return false;
    String isFree =
        e.isFree == null ? '' : (e.isFree! ? loc.free : loc.pay);
    String isOutdoor = e.isOutdoor == null
        ? ''
        : (e.isOutdoor! ? loc.outdoor : loc.indoor);
    bool matchesKeywords = keywords.every((word) {
      bool matchedText = e.city.toLowerCase().contains(word) ||
          e.location.toLowerCase().contains(word) ||
          e.name.toLowerCase().contains(word) ||
          e.type.toLowerCase().contains(word) ||
          e.description.toLowerCase().contains(word) ||
          //e.fee.toLowerCase().contains(word) ||
          e.unit.toLowerCase().contains(word) ||
          isFree.toLowerCase().contains(word) ||
          isOutdoor.toLowerCase().contains(word);
      if (matchedText) {
        return matchedText;
      }
      // 🔹 年齡判斷
      final ageSingleMatch = ModelEvent.ageSingle.firstMatch(word);
      final ageRangeMatch = ModelEvent.ageRange.firstMatch(word);
      final priceMatch = ModelEvent.priceReg.firstMatch(word);

      if (ageRangeMatch != null) {
        final num kwStart = num.parse(ageRangeMatch.group(1)!);
        final num kwEnd = num.parse(ageRangeMatch.group(2)!);
        final num eStart = e.ageMin ?? 0;
        final num eEnd = e.ageMax ?? 999;
        // 🔹 區間有交集即可
        if (!(kwEnd < eStart || kwStart > eEnd)) {
          return true;
        }
      } else if (ageSingleMatch != null) {
        final num kwAge = num.parse(ageSingleMatch.group(1)!);
        if ((e.ageMin ?? 0) <= kwAge && (e.ageMax ?? 999) >= kwAge) {
          return true;
        }
      }

      // 🔹 價格判斷（主事件）
      if (priceMatch != null) {
        final num kwMin = num.parse(priceMatch.group(1)!);
        final num? kwMax =
            priceMatch.group(2) != null ? num.parse(priceMatch.group(2)!) : null;

        if (_matchPrice(
          kwMin: kwMin,
          kwMax: kwMax,
          priceMin: e.priceMin,
          priceMax: e.priceMax,
        )) {
          return true;
        }
      }

      bool matchedSubEvents = e.subEvents.any((se) {
        String sIsFree =
            se.isFree == null ? '' : (se.isFree! ? loc.free : loc.pay);
        String sIsOutdoor = se.isOutdoor == null
            ? ''
            : (se.isOutdoor! ? loc.outdoor : loc.indoor);
        bool matchedSEText = se.city.toLowerCase().contains(word) ||
            se.location.toLowerCase().contains(word) ||
            se.name.toLowerCase().contains(word) ||
            se.type.toLowerCase().contains(word) ||
            se.description.toLowerCase().contains(word) ||
            //se.fee.toLowerCase().contains(word) ||
            se.unit.toLowerCase().contains(word) ||
            sIsFree.toLowerCase().contains(word) ||
            sIsOutdoor.toLowerCase().contains(word);
        if (matchedSEText) {
          return matchedSEText;
        }
        // 子事件年齡判斷
        if (ageRangeMatch != null) {
          final num kwStart = num.parse(ageRangeMatch.group(1)!);
          final num kwEnd = num.parse(ageRangeMatch.group(2)!);
          final num seStart = se.ageMin ?? 0;
          final num seEnd = se.ageMax ?? 999;
          if (!(kwEnd < seStart || kwStart > seEnd)) {
            return true;
          }
        } else if (ageSingleMatch != null) {
          final num kwAge = num.parse(ageSingleMatch.group(1)!);
          if ((se.ageMin ?? 0) <= kwAge && (se.ageMax ?? 999) >= kwAge) {
            return true;
          }
        }

        // 🔹 子事件價格判斷
        if (priceMatch != null) {
          final num kwMin = num.parse(priceMatch.group(1)!);
          final num? kwMax =
              priceMatch.group(2) != null ? num.parse(priceMatch.group(2)!) : null;

          if (_matchPrice(
            kwMin: kwMin,
            kwMax: kwMax,
            priceMin: se.priceMin,
            priceMax: se.priceMax,
          )) {
            return true;
          }
        }
        return false;
      });
      return matchedSubEvents;
    });

    final endDate = e.endDate ?? e.startDate;
    bool matchesDate = true;
    filter.startDate = filter.startDate?.add(Duration(seconds: -1)).day ==
            filter.startDate?.day
        ? filter.startDate
        : filter.startDate?.add(Duration(days: 1)).add(Duration(seconds: -1));
    if (filter.startDate != null &&
        endDate != null &&
        !endDate.isAfter(filter.startDate!)) {
      matchesDate = false;
    }
    filter.endDate =
        filter.endDate?.add(Duration(seconds: -1)).day == filter.endDate?.day
            ? filter.endDate
            : filter.endDate?.add(Duration(days: 1)).add(Duration(seconds: -1));
    final startDate = e.startDate;
    if (filter.endDate != null &&
        startDate != null &&
        !startDate.isBefore(filter.endDate!)) {
      matchesDate = false;
    }

    return matchesKeywords && matchesDate;
  }).toList();
}

bool _matchPrice({
  required num kwMin,
  num? kwMax,
  required num? priceMin,
  required num? priceMax,
}) {
  final num eMin = (priceMin ?? 0);
  final num eMax = (priceMax ?? 999999);

  if (kwMax == null) {
    // 單一價格：100
    return eMin <= kwMin && eMax >= kwMin;
  } else {
    // 區間：100~200（有交集即可）
    return !(kwMax < eMin || kwMin > eMax);
  }
}
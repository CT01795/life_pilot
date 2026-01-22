import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/models/event/model_search_filter.dart';

bool _matchPrice({
  required int kwMin,
  int? kwMax,
  required double? priceMin,
  required double? priceMax,
}) {
  final int eMin = (priceMin ?? 0).toInt();
  final int eMax = (priceMax ?? 999999).toInt();

  if (kwMax == null) {
    // 單一價格：100
    return eMin <= kwMin && eMax >= kwMin;
  } else {
    // 區間：100~200（有交集即可）
    return !(kwMax < eMin || kwMin > eMax);
  }
}

List<EventItem> utilsFilterEvents({
  required List<EventItem> events,
  required SearchFilter filter,
  required Set<String> removedEventIds,
  required AppLocalizations loc,
}) {
  // 🧠 預先處理關鍵字（全部轉小寫）
  final List<String> keywords = filter.keywords
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();

  if (keywords.isEmpty && filter.startDate == null && removedEventIds.isEmpty) {
    // ✅ 若沒有過濾條件，直接回傳原列表（避免無謂運算）
    return List<EventItem>.from(events);
  }
  RegExp ageSingle = RegExp(r'^(\d+)y$'); // 例如 "18y"
  RegExp ageRange = RegExp(r'^(\d+)y~(\d+)y$'); // 例如 "18y~25y"
  RegExp priceReg = RegExp(r'^\$?(\d+)(?:~\$?(\d+))?$');
  return events.where((e) {
    if (removedEventIds.contains(e.id)) return false;
    String isFree =
        e.isFree == null ? constEmpty : (e.isFree! ? loc.free : loc.pay);
    String isOutdoor = e.isOutdoor == null
        ? constEmpty
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
      final ageSingleMatch = ageSingle.firstMatch(word);
      final ageRangeMatch = ageRange.firstMatch(word);
      final priceMatch = priceReg.firstMatch(word);

      if (ageRangeMatch != null) {
        final int kwStart = int.parse(ageRangeMatch.group(1)!);
        final int kwEnd = int.parse(ageRangeMatch.group(2)!);
        final int eStart = e.ageMin ?? 0;
        final int eEnd = e.ageMax ?? 999;
        // 🔹 區間有交集即可
        if (!(kwEnd < eStart || kwStart > eEnd)) {
          return true;
        }
      } else if (ageSingleMatch != null) {
        final int kwAge = int.parse(ageSingleMatch.group(1)!);
        if ((e.ageMin ?? 0) <= kwAge && (e.ageMax ?? 999) >= kwAge) {
          return true;
        }
      }

      // 🔹 價格判斷（主事件）
      if (priceMatch != null) {
        final int kwMin = int.parse(priceMatch.group(1)!);
        final int? kwMax =
            priceMatch.group(2) != null ? int.parse(priceMatch.group(2)!) : null;

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
            se.isFree == null ? constEmpty : (se.isFree! ? loc.free : loc.pay);
        String sIsOutdoor = se.isOutdoor == null
            ? constEmpty
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
          final int kwStart = int.parse(ageRangeMatch.group(1)!);
          final int kwEnd = int.parse(ageRangeMatch.group(2)!);
          final int seStart = se.ageMin ?? 0;
          final int seEnd = se.ageMax ?? 999;
          if (!(kwEnd < seStart || kwStart > seEnd)) {
            return true;
          }
        } else if (ageSingleMatch != null) {
          final int kwAge = int.parse(ageSingleMatch.group(1)!);
          if ((se.ageMin ?? 0) <= kwAge && (se.ageMax ?? 999) >= kwAge) {
            return true;
          }
        }

        // 🔹 子事件價格判斷
        if (priceMatch != null) {
          final int kwMin = int.parse(priceMatch.group(1)!);
          final int? kwMax =
              priceMatch.group(2) != null ? int.parse(priceMatch.group(2)!) : null;

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

import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/date_time.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_base.dart';

class EventViewModel {
  final String id;
  final String name;
  final bool showDate;
  final String dateRange;
  List<String> tags;
  final bool hasLocation;
  final String locationDisplay;
  final String? masterUrl;
  final String description;
  final List<EventViewModel> subEvents;
  final bool canDelete;
  final bool showSubEvents;
  final DateTime? startDate;
  final DateTime? endDate;
  final num? ageMin;
  final num? ageMax;
  final bool? isFree;
  final num? priceMin;
  final num? priceMax;
  final bool? isOutdoor;
  final bool? isLike;
  final bool? isDislike;
  final int? pageViews;
  final int? cardClicks;
  final int? saves;
  final int? registrationClicks;
  final int? likeCounts;
  final int? dislikeCounts;

  EventViewModel({
    required this.id,
    required this.name,
    required this.showDate,
    required this.startDate,
    required this.endDate,
    required this.dateRange,
    required this.tags,
    required this.hasLocation,
    required this.locationDisplay,
    this.masterUrl,
    this.description = constEmpty,
    this.subEvents = const [],
    this.canDelete = false,
    this.showSubEvents = true,
    this.ageMin,
    this.ageMax,
    this.isFree,
    this.priceMin,
    this.priceMax,
    this.isOutdoor,
    this.isLike,
    this.isDislike,
    this.pageViews,
    this.cardClicks,
    this.saves,
    this.registrationClicks,
    this.likeCounts,
    this.dislikeCounts,
  });

  // ---------------------------------------------------------------------------
  // 🧩 UI 資料封裝
  // ---------------------------------------------------------------------------
  static EventViewModel buildEventViewModel({
    required EventBase event,
    required String parentLocation,
    required bool canDelete,
    bool showSubEvents = true,
    required AppLocalizations loc,
    required String tableName,
  }) {
    final locationDisplay = (event.city.isNotEmpty || event.location.isNotEmpty)
        ? '${event.city}．${event.location}'
        : constEmpty;

    String isFree = event.isFree == null
        ? constEmpty
        : (event.isFree! ? loc.free : loc.pay);
    String isOutdoor = event.isOutdoor == null
        ? constEmpty
        : (event.isOutdoor! ? loc.outdoor : loc.indoor);
    String ageRange = event.ageMin == null
        ? constEmpty
        : "${event.ageMin}y~${event.ageMax == null ? constEmpty : "${event.ageMax}y"}";
    String priceRange = event.priceMin == null
        ? constEmpty
        : "\$${event.priceMin}~${event.priceMax == null ? constEmpty : "\$${event.priceMax}"}";
    // 處理 tags
    final tagsRawData = <String>[
      isFree,
      isOutdoor,
      ageRange,
      priceRange,
      event.type
    ].where((t) => t.isNotEmpty).toList();

    final tags = tagsRawData
        .expand((t) => t.split(RegExp(r'[\s,，]')))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .take(3)
        .toList();

    return EventViewModel(
      id: event.id,
      name: event.name,
      showDate: tableName != TableNames.recommendedAttractions,
      startDate: event.startDate,
      endDate: event.endDate,
      dateRange: tableName != TableNames.recommendedAttractions
          ? '${DateTimeFormatter.formatEventDateTime(event, CalendarMisc.startToS)}'
              '${DateTimeFormatter.formatEventDateTime(event, CalendarMisc.endToE)}'
          : constEmpty,
      tags: tags,
      hasLocation:
          locationDisplay.isNotEmpty && locationDisplay != parentLocation,
      locationDisplay: locationDisplay,
      masterUrl: event.masterUrl,
      description: event.description,
      subEvents: showSubEvents
          ? event.subEvents
              .map((sub) => buildEventViewModel(
                  event: sub,
                  parentLocation: locationDisplay,
                  canDelete: canDelete,
                  showSubEvents: showSubEvents,
                  loc: loc,
                  tableName: tableName))
              .toList()
          : const [],
      canDelete: canDelete,
      showSubEvents: showSubEvents,
      ageMin: event.ageMin,
      ageMax: event.ageMax,
      isFree: event.isFree,
      priceMin: event.priceMin,
      priceMax: event.priceMax,
      isOutdoor: event.isOutdoor,
      isLike: event.isLike,
      isDislike: event.isDislike,
      pageViews: event.pageViews,
      cardClicks: event.cardClicks,
      saves: event.saves,
      registrationClicks: event.registrationClicks,
      likeCounts: event.likeCounts,
      dislikeCounts: event.dislikeCounts,
    );
  }
}

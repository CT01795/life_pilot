import 'package:life_pilot/core/const.dart';

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
}
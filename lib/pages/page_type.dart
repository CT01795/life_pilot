import 'package:life_pilot/l10n/app_localizations.dart';

enum PageType {
  personalEvent,
  settings,
  recommendedEvent,
  recommendedAttractions,
  memoryTrace,
  accountRecords,
  pointsRecord,
  game,
  ai,
  feedbackAdmin,
  businessPlan,
}

extension PageTypeExtension on PageType {
  //Dart 的 enum 自 2.15 以後有內建 name 屬性，會直接返回 enum 變數名稱字串，因此不用寫明確的 switch：
  String get key => name; //ex PageType.personalEvent 會返回 'personalEvent'

  static final Map<String, PageType> _keyMap = {
    for (var e in PageType.values) e.key: e,
  };

  //fromKey 改寫成 Map 快取（優化搜尋效率）
  //目前 fromKey 會用 firstWhere 遍歷所有值，當 enum 值很多時效率會下降。可以用一個靜態 Map 快取字串到 enum 的對應關係：
  static PageType fromKey(String key) =>
      _keyMap[key] ?? PageType.recommendedEvent;

  String title({required AppLocalizations loc}) {
    final map = _titlesForLocale(loc);
    return map[this]!;
  }

  static Map<PageType, String> _titlesForLocale(AppLocalizations loc) => {
    PageType.personalEvent: loc.personalEvent,
    PageType.settings: loc.settings,
    PageType.recommendedEvent: loc.recommendedEvent,
    PageType.recommendedAttractions: loc.recommendedAttractions,
    PageType.memoryTrace: loc.memoryTrace,
    PageType.accountRecords: loc.accountRecords,
    PageType.pointsRecord: loc.pointsRecord,
    PageType.game: loc.game,
    PageType.ai: loc.ai,
    PageType.feedbackAdmin: loc.feedback,
    PageType.businessPlan: loc.businessPlan,
  };
}

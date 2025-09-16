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
}

extension PageTypeExtension on PageType {
  String key() {
    switch (this) {
      case PageType.personalEvent:
        return 'personalEvent';
      case PageType.settings:
        return 'settings';
      case PageType.recommendedEvent:
        return 'recommendedEvent';
      case PageType.recommendedAttractions:
        return 'recommendedAttractions';
      case PageType.memoryTrace:
        return 'memoryTrace';
      case PageType.accountRecords:
        return 'accountRecords';
      case PageType.pointsRecord:
        return 'pointsRecord';
      case PageType.game:
        return 'game';
      case PageType.ai:
        return 'ai';
    }
  }

  static PageType? fromKey(String key) {
    return PageType.values.firstWhere(
      (e) => e.key() == key,
      orElse: () => PageType.recommendedEvent, // 預設頁
    );
  }

  String title(AppLocalizations loc) {
    switch (this) {
      case PageType.personalEvent:
        return loc.personal_event;
      case PageType.settings:
        return loc.settings;
      case PageType.recommendedEvent:
        return loc.recommended_event;
      case PageType.recommendedAttractions:
        return loc.recommended_attractions;
      case PageType.memoryTrace:
        return loc.memory_trace;
      case PageType.accountRecords:
        return loc.account_records;
      case PageType.pointsRecord:
        return loc.points_record;
      case PageType.game:
        return loc.game;
      case PageType.ai:
        return loc.ai;
    }
  }
}

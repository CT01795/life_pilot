import 'package:life_pilot/l10n/app_localizations.dart';

abstract final class RecordCategories {
  static const uncategorized = 'uncategorized';

  static const accounting = <String>[
    uncategorized,
    'food',
    'clothing',
    'housing',
    'transportation',
    'education',
    'entertainment',
  ];

  static const points = <String>[
    uncategorized,
    'virtue',
    'intelligence',
    'fitness',
    'social',
    'arts',
  ];

  static String label(AppLocalizations loc, String category) {
    return switch (category) {
      'food' => loc.recordCategoryFood,
      'clothing' => loc.recordCategoryClothing,
      'housing' => loc.recordCategoryHousing,
      'transportation' => loc.recordCategoryTransportation,
      'education' => loc.recordCategoryEducation,
      'entertainment' => loc.recordCategoryEntertainment,
      'virtue' => loc.recordCategoryVirtue,
      'intelligence' => loc.recordCategoryIntelligence,
      'fitness' => loc.recordCategoryFitness,
      'social' => loc.recordCategorySocial,
      'arts' => loc.recordCategoryArts,
      _ => loc.recordCategoryUncategorized,
    };
  }
}

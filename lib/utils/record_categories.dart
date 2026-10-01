import 'package:life_pilot/l10n/app_localizations.dart';

abstract final class RecordCategories {
  static const uncategorized = 'uncategorized';
  static const reserved = 'reserved';

  static const accountingIncome = <String>[
    uncategorized,
    'salary',
    'bonus',
    'investment_income',
    'allowance',
    'refund',
    'other_income',
  ];

  static const accountingExpense = <String>[
    uncategorized,
    'food',
    'clothing',
    'housing',
    'transportation',
    'education',
    'entertainment',
  ];

  static const accounting = <String>[
    uncategorized,
    reserved,
    'salary',
    'bonus',
    'investment_income',
    'allowance',
    'refund',
    'other_income',
    'food',
    'clothing',
    'housing',
    'transportation',
    'education',
    'entertainment',
  ];

  static const points = <String>[
    uncategorized,
    reserved,
    'virtue',
    'intelligence',
    'fitness',
    'social',
    'arts',
  ];

  static String label(AppLocalizations loc, String category) {
    return switch (category) {
      reserved => loc.recordCategoryReserved,
      'salary' => loc.recordCategorySalary,
      'bonus' => loc.recordCategoryBonus,
      'investment_income' => loc.recordCategoryInvestmentIncome,
      'allowance' => loc.recordCategoryAllowance,
      'refund' => loc.recordCategoryRefund,
      'other_income' => loc.recordCategoryOtherIncome,
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

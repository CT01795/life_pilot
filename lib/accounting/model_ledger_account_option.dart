import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/record_row_utils.dart';
import 'package:life_pilot/utils/value_parser.dart';

/// Lightweight account identity used by pickers that do not display totals.
class ModelLedgerAccountOption {
  const ModelLedgerAccountOption({
    required this.id,
    required this.name,
    required this.category,
  });

  factory ModelLedgerAccountOption.fromRow(RecordRow row) =>
      ModelLedgerAccountOption(
        id: parseStringValue(row[Fields.id]),
        name: parseStringValue(row[Fields.account]),
        category: parseStringValue(row['category']),
      );

  final String id;
  final String name;
  final String category;

  /// Mirrors the cloud picker rule without loading balances or detail rows.
  static List<ModelLedgerAccountOption> selectLocal(
    Iterable<RecordRow> rows, {
    required int projectLimit,
  }) {
    if (projectLimit < 0) {
      throw ArgumentError.value(projectLimit, 'projectLimit');
    }
    final personal =
        rows
            .where(
              (row) =>
                  row[Fields.isValid] == true && row['category'] == 'personal',
            )
            .toList()
          ..sort((a, b) {
            final byName = parseStringValue(
              a[Fields.account],
            ).compareTo(parseStringValue(b[Fields.account]));
            return byName != 0
                ? byName
                : parseStringValue(
                    a[Fields.id],
                  ).compareTo(parseStringValue(b[Fields.id]));
          });
    final projects =
        rows
            .where(
              (row) =>
                  row[Fields.isValid] == true && row['category'] == 'project',
            )
            .toList()
          ..sort((a, b) {
            final byCreated = parseStringValue(
              b[Fields.createdAt],
            ).compareTo(parseStringValue(a[Fields.createdAt]));
            return byCreated != 0
                ? byCreated
                : parseStringValue(
                    a[Fields.id],
                  ).compareTo(parseStringValue(b[Fields.id]));
          });
    return List.unmodifiable(
      [
        ...personal,
        ...projects.take(projectLimit),
      ].map(ModelLedgerAccountOption.fromRow),
    );
  }
}

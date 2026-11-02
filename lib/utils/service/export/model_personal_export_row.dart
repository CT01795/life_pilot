/// Translates the compact SQL projection into the existing Excel input shape.
/// Unknown fields never reach the workbook, even if the RPC grows new columns.
class PersonalExportRow {
  const PersonalExportRow._(this.values);
  final Map<String, dynamic> values;

  factory PersonalExportRow.fromWire(
    Map<String, dynamic> row, {
    required bool nested,
    required Iterable<String> fields,
  }) {
    final table = row['table_name'];
    final record = nested ? row['record'] : row;
    if (table is! String || record is! Map) {
      throw const FormatException('Invalid Excel export projection');
    }
    return PersonalExportRow._(
      Map<String, dynamic>.unmodifiable({
        'table_name': table,
        // Rebuild absent keys locally: the existing workbook uses key presence
        // when choosing columns. This keeps headers identical to legacy SQL.
        for (final field in fields) field: record[field],
      }),
    );
  }
}

import 'package:life_pilot/utils/value_parser.dart';

/// Searchable fields belong to a data snapshot. Replace this index on updates.
/// Only the most recent query is cached, so typing cannot grow the cache.
class StockSearchIndex<T> {
  StockSearchIndex({
    required Iterable<T> rows,
    required Iterable<String> Function(T) fields,
  }) : rows = List<T>.unmodifiable(rows) {
    _fields = this.rows
        .map(
          (row) => fields(
            row,
          ).map((field) => field.toLowerCase()).toList(growable: false),
        )
        .toList(growable: false);
  }

  final List<T> rows;
  late final List<List<String>> _fields;
  String? _lastQuery;
  List<T>? _lastResult;

  List<T> filter(String keyword) {
    final query = normalizeStringValue(keyword);
    if (query.isEmpty) return rows;
    if (query == _lastQuery) return _lastResult!;
    final matches = <T>[];
    for (var i = 0; i < rows.length; i++) {
      if (_fields[i].any((field) => field.contains(query))) {
        matches.add(rows[i]);
      }
    }
    _lastQuery = query;
    return _lastResult = List<T>.unmodifiable(matches);
  }
}

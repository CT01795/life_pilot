import 'package:life_pilot/utils/value_parser.dart';

/// Searchable fields belong to a data snapshot. Replace this index on updates.
/// Only the most recent query is cached, so typing cannot grow the cache.
/// Capture strings immediately, but normalize them only on the first search.
class StockSearchIndex<T> {
  StockSearchIndex({
    required Iterable<T> rows,
    required Iterable<String> Function(T) fields,
  }) : rows = List<T>.unmodifiable(rows) {
    _fields = this.rows
        .map((row) => fields(row).toList(growable: false))
        .toList(growable: false);
  }

  final List<T> rows;
  late final List<List<String>> _fields;
  bool _normalized = false;
  String? _lastQuery;
  List<T>? _lastResult;
  List<int> _lastMatches = const [];

  List<T> filter(String keyword) {
    final query = normalizeStringValue(keyword);
    if (query.isEmpty) return rows;
    if (query == _lastQuery) return _lastResult!;
    _normalizeFields();
    final matchingIndices = <int>[];
    var unchanged = _lastResult != null;
    // A stricter substring query cannot match a previously excluded row.
    // Backspacing or replacing a keyword must instead scan the full snapshot.
    final candidates = _lastQuery != null && query.contains(_lastQuery!)
        ? _lastMatches
        : Iterable<int>.generate(rows.length);
    for (final i in candidates) {
      if (_fields[i].any((field) => field.contains(query))) {
        if (unchanged &&
            (matchingIndices.length >= _lastMatches.length ||
                _lastMatches[matchingIndices.length] != i)) {
          unchanged = false;
        }
        matchingIndices.add(i);
      }
    }
    _lastQuery = query;
    // Reuse the last immutable result when only the keyword changed. This
    // avoids allocating another row list and rebuilding identical sections.
    if (unchanged && matchingIndices.length == _lastMatches.length) {
      return _lastResult!;
    }
    _lastMatches = matchingIndices;
    return _lastResult = matchingIndices.length == rows.length
        ? rows
        : List<T>.unmodifiable(matchingIndices.map((i) => rows[i]));
  }

  void _normalizeFields() {
    if (_normalized) return;
    // Reuse the captured lists; do not retain a second normalized index or
    // reread mutable models when the first keyword is entered.
    for (final fields in _fields) {
      for (var i = 0; i < fields.length; i++) {
        fields[i] = fields[i].toLowerCase();
      }
    }
    _normalized = true;
  }
}

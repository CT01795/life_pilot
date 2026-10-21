import 'package:life_pilot/utils/text_normalization.dart';

/// One owner-scoped, read-only search projection. Replace the source list when
/// records change; [presentationKey] must cover locale/other valuesOf inputs.
/// Keeps only the current snapshot; no network, context or widgets retained.
class ModelKeywordProjection<T> {
  List<T>? _source;
  Object? _presentationKey;
  List<List<String>>? _texts;
  String? _keyword;
  List<T>? _result;

  List<T> select({
    required List<T> source,
    required String keyword,
    required Iterable<String> Function(T item) valuesOf,
    Object? presentationKey,
  }) {
    if (!identical(_source, source) || _presentationKey != presentationKey) {
      _source = source;
      _presentationKey = presentationKey;
      _texts = null;
      _keyword = null;
      _result = null;
    }
    final normalized = normalizeText(keyword);
    if (_keyword == normalized && _result != null) return _result!;
    if (normalized.isEmpty) {
      _keyword = normalized;
      return _result = source;
    }
    final texts = _texts ??= [
      for (final item in source)
        valuesOf(item).map(normalizeText).toList(growable: false),
    ];
    final result = List<T>.unmodifiable([
      for (var i = 0; i < source.length; i++)
        if (texts[i].any((value) => value.contains(normalized))) source[i],
    ]);
    _keyword = normalized;
    return _result = result;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/model_keyword_projection.dart';
import 'package:life_pilot/utils/text_normalization.dart';

void main() {
  test('empty queries reuse source without reading or indexing values', () {
    final source = ['A', 'B'];
    final projection = ModelKeywordProjection<String>();
    expect(
      projection.select(
        source: source,
        keyword: '  ',
        valuesOf: (_) => throw StateError('unneeded'),
      ),
      same(source),
    );
  });

  test(
    'normalization, multiple fields and duplicates match previous filtering',
    () {
      final source = [' Alice@Example.com ', 'B', ' Alice@Example.com '];
      final projection = ModelKeywordProjection<String>();
      for (final query in ['ALICE', ' example ', '2026/10/21', 'missing', '']) {
        Iterable<String> values(String value) => [value, '2026/10/21'];
        final normalized = normalizeText(query);
        final reference = source
            .where(
              (item) =>
                  normalized.isEmpty ||
                  values(
                    item,
                  ).any((v) => normalizeText(v).contains(normalized)),
            )
            .toList();
        expect(
          projection.select(source: source, keyword: query, valuesOf: values),
          reference,
        );
      }
    },
  );

  test(
    'checkbox rebuilds and equivalent queries reuse results and text index',
    () {
      final source = ['Alice', 'Bob'];
      var reads = 0;
      Iterable<String> values(String value) {
        reads++;
        return [value];
      }

      final projection = ModelKeywordProjection<String>();
      final first = projection.select(
        source: source,
        keyword: 'alice',
        valuesOf: values,
      );
      for (var i = 0; i < 20; i++) {
        expect(
          projection.select(
            source: source,
            keyword: ' ALICE ',
            valuesOf: values,
          ),
          same(first),
        );
      }
      expect(reads, 2);
      expect(
        projection.select(source: source, keyword: 'bob', valuesOf: values),
        ['Bob'],
      );
      expect(reads, 2);
      expect(() => first.clear(), throwsUnsupportedError);
    },
  );

  test('new snapshots release old account and edited content', () {
    final projection = ModelKeywordProjection<String>();
    List<String> select(List<String> source) =>
        projection.select(source: source, keyword: 'a', valuesOf: (v) => [v]);
    final old = select(['Alice']);
    expect(select(['Bob']), isEmpty);
    expect(select(['Ada']), ['Ada']);
    expect(old, ['Alice']);
  });

  test('presentation changes refresh locale-dependent date search text', () {
    final source = ['event'];
    final projection = ModelKeywordProjection<String>();
    final english = projection.select(
      source: source,
      keyword: '10/21',
      presentationKey: 'en',
      valuesOf: (_) => ['10/21/2026'],
    );
    expect(english, ['event']);
    expect(
      projection.select(
        source: source,
        keyword: '10/21',
        presentationKey: 'ja',
        valuesOf: (_) => ['2026/10/21'],
      ),
      ['event'],
    );
    expect(
      projection.select(
        source: source,
        keyword: '10/21/2026',
        presentationKey: 'ja',
        valuesOf: (_) => throw StateError('already indexed'),
      ),
      isEmpty,
    );
  });

  test('independent section projections never replace each other results', () {
    final source = ['Alice', 'Bob'];
    final sent = ModelKeywordProjection<String>();
    final received = ModelKeywordProjection<String>();
    final first = sent.select(
      source: source,
      keyword: 'alice',
      valuesOf: (v) => [v],
    );
    expect(
      received.select(source: source, keyword: 'bob', valuesOf: (v) => [v]),
      ['Bob'],
    );
    expect(
      sent.select(
        source: source,
        keyword: 'alice',
        valuesOf: (_) => throw StateError('cached'),
      ),
      same(first),
    );
  });

  test('failed text projection can retry without returning a stale result', () {
    final projection = ModelKeywordProjection<String>();
    final source = ['Alice'];
    var fail = true;
    Iterable<String> values(String value) {
      if (fail) throw StateError('retry');
      return [value];
    }

    expect(
      projection.select(source: source, keyword: '', valuesOf: values),
      source,
    );
    expect(
      () =>
          projection.select(source: source, keyword: 'alice', valuesOf: values),
      throwsStateError,
    );
    fail = false;
    expect(
      projection.select(source: source, keyword: 'alice', valuesOf: values),
      ['Alice'],
    );
  });

  test('field matching cannot span adjacent values', () {
    final projection = ModelKeywordProjection<int>();
    expect(
      projection.select(
        source: [1],
        keyword: 'icebob',
        valuesOf: (_) => ['Alice', 'Bob'],
      ),
      isEmpty,
    );
  });
}

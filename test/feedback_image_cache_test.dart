import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/feedback/model_feedback.dart';

ModelFeedback _model(
  List<String>? images,
  Future<Uint8List> Function(String) decode,
) => ModelFeedback(
  id: 1,
  subject: '',
  content: '',
  createdAt: DateTime(2026),
  screenshot: images,
  screenshotDecoder: decode,
);
Uint8List _bytes(int value) => Uint8List.fromList([value]);

void main() {
  for (final bulk in [false, true]) {
    for (final fails in [false, true]) {
      test(
        'decoder re-entry shares the registered future (bulk=$bulk, failure=$fails)',
        () async {
          late ModelFeedback model;
          Future<Object?>? joined;
          final pending = Completer<Uint8List>();
          var calls = 0;
          model = _model(['image'], (_) {
            calls++;
            if (calls == 1) {
              joined = bulk
                  ? model.decodeScreenshotsAsync()
                  : model.decodeScreenshotAsync(0);
            }
            if (fails) throw StateError('decoder');
            return pending.future;
          });
          final first = bulk
              ? model.decodeScreenshotsAsync()
              : model.decodeScreenshotAsync(0);
          expect(joined, same(first));
          expect(calls, 1);
          if (fails) {
            if (bulk) {
              await expectLater(first, throwsStateError);
            } else {
              expect(await first, isNull);
            }
          } else {
            pending.complete(_bytes(1));
            expect(
              await first,
              bulk
                  ? [
                      [1],
                    ]
                  : [1],
            );
          }
        },
      );
    }

    test(
      'reentrant image replacement retains the newer future (bulk=$bulk)',
      () async {
        late ModelFeedback model;
        Future<Object?>? replacement;
        final old = Completer<Uint8List>(), fresh = Completer<Uint8List>();
        final calls = <String>[];
        model = _model(['old'], (source) {
          calls.add(source);
          if (source == 'old') {
            model.screenshot = ['new'];
            replacement = bulk
                ? model.decodeScreenshotsAsync()
                : model.decodeScreenshotAsync(0);
            return old.future;
          }
          return fresh.future;
        });
        final first = bulk
            ? model.decodeScreenshotsAsync()
            : model.decodeScreenshotAsync(0);
        fresh.complete(_bytes(2));
        expect(
          await replacement,
          bulk
              ? [
                  [2],
                ]
              : [2],
        );
        old.complete(_bytes(1));
        expect(
          await first,
          bulk
              ? [
                  [1],
                ]
              : [1],
        );
        if (bulk) {
          expect(model.screenshotDecodeRawData!.single, [2]);
        } else {
          expect(model.decodeScreenshotAsync(0), same(replacement));
        }
        expect(calls, ['old', 'new']);
      },
    );
  }

  for (final synchronous in [false, true]) {
    for (final lateFailure in [false, true]) {
      test(
        'bulk failure releases retry without waiting for sibling (sync=$synchronous, late error=$lateFailure)',
        () async {
          var fail = true;
          final pending = Completer<Uint8List>();
          final model = _model(['bad', 'pending'], (source) {
            if (fail) {
              if (source == 'pending') return pending.future;
              if (synchronous) throw StateError('bad image');
              return Future.error(StateError('bad image'));
            }
            return Future.value(_bytes(source == 'bad' ? 1 : 2));
          });
          await expectLater(model.decodeScreenshotsAsync(), throwsStateError);
          expect(pending.isCompleted, isFalse);
          expect(model.screenshotDecodeRawData, isNull);
          fail = false;
          final retried = await model.decodeScreenshotsAsync();
          expect(retried, [
            [1],
            [2],
          ]);
          if (lateFailure) {
            pending.completeError(StateError('late sibling'));
          } else {
            pending.complete(_bytes(9));
          }
          await Future<void>.delayed(Duration.zero);
          expect(model.screenshotDecodeRawData, same(retried));
        },
      );
    }
  }

  test('single-image reads are lazy and share the exact future', () async {
    final calls = <String>[];
    final done = Completer<Uint8List>();
    final model = _model(['first', 'untouched'], (source) {
      calls.add(source);
      return done.future;
    });
    final first = model.decodeScreenshotAsync(0);
    expect(model.decodeScreenshotAsync(0), same(first));
    expect(calls, ['first']);
    done.complete(_bytes(1));
    expect(await first, [1]);
    expect(model.decodeScreenshotAsync(0), same(first));
    expect(await model.decodeScreenshotAsync(2), isNull);
    expect(await model.decodeScreenshotAsync(-1), isNull);
  });
  test('in-place replacement invalidates only the changed image', () async {
    final calls = <String>[];
    final model = _model(['1', '2'], (source) async {
      calls.add(source);
      return _bytes(int.parse(source));
    });
    final first = model.decodeScreenshotAsync(0),
        second = model.decodeScreenshotAsync(1);
    await Future.wait([first, second]);
    model.screenshot![0] = '3';
    final changed = model.decodeScreenshotAsync(0);
    expect(changed, isNot(same(first)));
    expect(await changed, [3]);
    expect(model.decodeScreenshotAsync(1), same(second));
    expect(calls, ['1', '2', '3']);
  });
  test(
    'late single-image completion cannot replace a newer image future',
    () async {
      final old = Completer<Uint8List>(), fresh = Completer<Uint8List>();
      final model = _model([
        'old',
      ], (source) => source == 'old' ? old.future : fresh.future);
      final a = model.decodeScreenshotAsync(0);
      model.screenshot = ['new'];
      final b = model.decodeScreenshotAsync(0);
      fresh.complete(_bytes(2));
      expect(await b, [2]);
      old.complete(_bytes(1));
      expect(await a, [1]);
      expect(model.decodeScreenshotAsync(0), same(b));
    },
  );
  test('bulk calls share a snapshot and the exact future', () async {
    final pending = <String, Completer<Uint8List>>{};
    final model = _model([
      'a',
      'b',
    ], (source) => (pending[source] = Completer<Uint8List>()).future);
    final first = model.decodeScreenshotsAsync();
    expect(model.decodeScreenshotsAsync(), same(first));
    pending['a']!.complete(_bytes(1));
    pending['b']!.complete(_bytes(2));
    expect(await first, [
      [1],
      [2],
    ]);
  });
  test(
    'late bulk success does not overwrite a newer decoded snapshot',
    () async {
      final old = Completer<Uint8List>(), fresh = Completer<Uint8List>();
      final model = _model([
        'old',
      ], (source) => source == 'old' ? old.future : fresh.future);
      final a = model.decodeScreenshotsAsync();
      model.screenshot = ['new'];
      final b = model.decodeScreenshotsAsync();
      final bytes = _bytes(2);
      fresh.complete(bytes);
      await b;
      old.complete(_bytes(1));
      await a;
      expect(model.screenshotDecodeRawData!.single, same(bytes));
    },
  );
  test('late bulk error cannot evict a newer in-flight snapshot', () async {
    final old = Completer<Uint8List>(), fresh = Completer<Uint8List>();
    final model = _model([
      'old',
    ], (source) => source == 'old' ? old.future : fresh.future);
    final a = model.decodeScreenshotsAsync();
    final observed = expectLater(a, throwsStateError);
    model.screenshot = ['new'];
    final b = model.decodeScreenshotsAsync();
    old.completeError(StateError('old failure'));
    await observed;
    expect(model.decodeScreenshotsAsync(), same(b));
    fresh.complete(_bytes(2));
    await b;
  });
  test(
    'bulk synchronous decoder failure is retryable for the same source',
    () async {
      var fails = true, calls = 0;
      final model = _model(['same'], (_) {
        calls++;
        if (fails) throw StateError('decoder');
        return Future.value(_bytes(1));
      });
      await expectLater(model.decodeScreenshotsAsync(), throwsStateError);
      fails = false;
      expect(await model.decodeScreenshotsAsync(), [
        [1],
      ]);
      expect(calls, 2);
    },
  );
  test(
    'missing single image is cached but source replacement can decode again',
    () async {
      final model = _model(['bad'], (source) async {
        if (source == 'bad') throw StateError('bad');
        return _bytes(1);
      });
      final missing = model.decodeScreenshotAsync(0);
      expect(await missing, isNull);
      expect(model.decodeScreenshotAsync(0), same(missing));
      model.screenshot![0] = 'good';
      expect(await model.decodeScreenshotAsync(0), [1]);
    },
  );
  test(
    'predecoded image cache is reused by lazy thumbnails without another worker',
    () async {
      var calls = 0;
      final model = _model(['unused'], (_) async {
        calls++;
        return _bytes(9);
      });
      final decoded = [_bytes(1)];
      model.screenshotDecodeRawData = decoded;
      expect(await model.decodeScreenshotAsync(0), same(decoded.single));
      expect(await model.decodeScreenshotsAsync(), same(decoded));
      expect(model.screenshotDecodeData, same(decoded));
      expect(calls, 0);
    },
  );
  test(
    'source edits invalidate raw cache while retaining synchronous API behavior',
    () async {
      final model = _model(['AQID'], (_) async => _bytes(9));
      expect(model.screenshotDecodeData!.single, [1, 2, 3]);
      model.screenshot![0] = 'BAUG';
      expect(model.screenshotDecodeRawData, isNull);
      final decoded = model.screenshotDecodeData!;
      expect(decoded.single, [4, 5, 6]);
      expect(await model.decodeScreenshotAsync(0), same(decoded.single));
    },
  );
  test(
    'manual cache seeding is not overwritten by an older bulk read',
    () async {
      final pending = Completer<Uint8List>();
      final model = _model(['image'], (_) => pending.future);
      final old = model.decodeScreenshotsAsync();
      final seeded = [_bytes(7)];
      model.screenshotDecodeRawData = seeded;
      pending.complete(_bytes(1));
      await old;
      expect(model.screenshotDecodeRawData, same(seeded));
    },
  );
  test(
    'source change without another bulk read cannot publish stale cache',
    () async {
      final pending = Completer<Uint8List>();
      final model = _model(['old'], (_) => pending.future);
      final old = model.decodeScreenshotsAsync();
      model.screenshot = ['new'];
      pending.complete(_bytes(1));
      await old;
      expect(model.screenshotDecodeRawData, isNull);
    },
  );
  test('null and empty image sources do not invoke the decoder', () async {
    final model = _model(null, (_) => throw StateError('unexpected decode'));
    expect(await model.decodeScreenshotsAsync(), isEmpty);
    expect(await model.decodeScreenshotAsync(0), isNull);
    model.screenshot = [];
    expect(await model.decodeScreenshotsAsync(), isEmpty);
  });
}

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
  for (final fails in [false, true]) {
    test(
      'decoder re-entry shares the registered future (failure=$fails)',
      () async {
        late ModelFeedback model;
        Future<Uint8List?>? joined;
        final pending = Completer<Uint8List>();
        var calls = 0;
        model = _model(['image'], (_) {
          calls++;
          if (calls == 1) joined = model.decodeScreenshotAsync(0);
          if (fails) throw StateError('decoder');
          return pending.future;
        });
        final first = model.decodeScreenshotAsync(0);
        expect(joined, same(first));
        expect(calls, 1);
        if (fails) {
          expect(await first, isNull);
        } else {
          pending.complete(_bytes(1));
          expect(await first, [1]);
        }
      },
    );
  }

  test('reentrant image replacement retains the newer future', () async {
    late ModelFeedback model;
    Future<Uint8List?>? replacement;
    final old = Completer<Uint8List>(), fresh = Completer<Uint8List>();
    final calls = <String>[];
    model = _model(['old'], (source) {
      calls.add(source);
      if (source == 'old') {
        model.screenshot = ['new'];
        replacement = model.decodeScreenshotAsync(0);
        return old.future;
      }
      return fresh.future;
    });
    final first = model.decodeScreenshotAsync(0);
    fresh.complete(_bytes(2));
    expect(await replacement, [2]);
    old.complete(_bytes(1));
    expect(await first, [1]);
    expect(model.decodeScreenshotAsync(0), same(replacement));
    expect(calls, ['old', 'new']);
  });

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

  for (final fails in [false, true]) {
    test(
      'late completion cannot replace a newer image (failure=$fails)',
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
        if (fails) {
          old.completeError(StateError('old failure'));
          expect(await a, isNull);
        } else {
          old.complete(_bytes(1));
          expect(await a, [1]);
        }
        expect(model.decodeScreenshotAsync(0), same(b));
      },
    );
  }

  for (final synchronous in [false, true]) {
    test('broken image does not block siblings (sync=$synchronous)', () async {
      final pending = Completer<Uint8List>();
      final model = _model(['bad', 'pending'], (source) {
        if (source == 'pending') return pending.future;
        if (synchronous) throw StateError('bad');
        return Future.error(StateError('bad'));
      });
      final bad = model.decodeScreenshotAsync(0);
      final sibling = model.decodeScreenshotAsync(1);
      expect(await bad, isNull);
      expect(pending.isCompleted, isFalse);
      pending.complete(_bytes(2));
      expect(await sibling, [2]);
      expect(model.decodeScreenshotAsync(0), same(bad));
    });
  }

  test(
    'missing image is cached; source replacement can decode again',
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
    'shrinking and replacing the list does not return removed images',
    () async {
      final calls = <String>[];
      final model = _model(['1', '2'], (source) async {
        calls.add(source);
        return _bytes(int.parse(source));
      });
      expect(await model.decodeScreenshotAsync(1), [2]);
      model.screenshot = ['1'];
      expect(await model.decodeScreenshotAsync(1), isNull);
      model.screenshot = ['1', '3'];
      expect(await model.decodeScreenshotAsync(1), [3]);
      expect(calls, ['2', '3']);
    },
  );

  test(
    'source change without another read cannot publish a stale future',
    () async {
      final old = Completer<Uint8List>();
      final model = _model([
        'old',
      ], (source) => source == 'old' ? old.future : Future.value(_bytes(2)));
      final first = model.decodeScreenshotAsync(0);
      model.screenshot = ['new'];
      old.complete(_bytes(1));
      expect(await first, [1]);
      expect(await model.decodeScreenshotAsync(0), [2]);
    },
  );

  test('null and empty image sources do not invoke the decoder', () async {
    final model = _model(null, (_) => throw StateError('unexpected decode'));
    expect(await model.decodeScreenshotAsync(0), isNull);
    model.screenshot = [];
    expect(await model.decodeScreenshotAsync(0), isNull);
    expect(await model.decodeScreenshotAsync(-1), isNull);
  });

  test('default decoder still decodes base64 through the lazy entry', () async {
    final model = ModelFeedback(
      id: 1,
      subject: '',
      content: '',
      createdAt: DateTime(2026),
      screenshot: ['AQID'],
    );
    expect(await model.decodeScreenshotAsync(0), [1, 2, 3]);
  });
}

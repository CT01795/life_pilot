import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/duplicate_tolerant_batch_writer.dart';

class _DuplicateError implements Exception {}

class _WriteError implements Exception {}

void main() {
  bool isDuplicate(Object error) => error is _DuplicateError;

  group('DuplicateTolerantBatchWriter', () {
    test('uses one batch write when there is no conflict', () async {
      var batchWrites = 0;
      var singleWrites = 0;

      await DuplicateTolerantBatchWriter.write(
        items: [1, 2, 3],
        writeBatch: (items) async => batchWrites++,
        writeOne: (item) async => singleWrites++,
        isDuplicateError: isDuplicate,
      );

      expect(batchWrites, 1);
      expect(singleWrites, 0);
    });

    test('retries individually and skips only duplicate rows', () async {
      final written = <int>[];
      final skipped = <int>[];

      await DuplicateTolerantBatchWriter.write(
        items: [1, 2, 3],
        writeBatch: (items) async => throw _DuplicateError(),
        writeOne: (item) async {
          if (item == 2) throw _DuplicateError();
          written.add(item);
        },
        isDuplicateError: isDuplicate,
        onDuplicate: skipped.add,
      );

      expect(written, [1, 3]);
      expect(skipped, [2]);
    });

    test('does not swallow a non-duplicate batch error', () async {
      await expectLater(
        DuplicateTolerantBatchWriter.write(
          items: [1],
          writeBatch: (items) async => throw _WriteError(),
          writeOne: (item) async {},
          isDuplicateError: isDuplicate,
        ),
        throwsA(isA<_WriteError>()),
      );
    });

    test('does not swallow a non-duplicate single-row error', () async {
      await expectLater(
        DuplicateTolerantBatchWriter.write(
          items: [1],
          writeBatch: (items) async => throw _DuplicateError(),
          writeOne: (item) async => throw _WriteError(),
          isDuplicateError: isDuplicate,
        ),
        throwsA(isA<_WriteError>()),
      );
    });
  });
}

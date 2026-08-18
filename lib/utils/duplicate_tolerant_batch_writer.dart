class DuplicateTolerantBatchWriter {
  const DuplicateTolerantBatchWriter._();

  static Future<void> write<T>({
    required List<T> items,
    required Future<void> Function(List<T> items) writeBatch,
    required Future<void> Function(T item) writeOne,
    required bool Function(Object error) isDuplicateError,
    void Function(T item)? onDuplicate,
  }) async {
    if (items.isEmpty) return;

    try {
      await writeBatch(items);
      return;
    } catch (error) {
      if (!isDuplicateError(error)) rethrow;
    }

    for (final item in items) {
      try {
        await writeOne(item);
      } catch (error) {
        if (!isDuplicateError(error)) rethrow;
        onDuplicate?.call(item);
      }
    }
  }
}

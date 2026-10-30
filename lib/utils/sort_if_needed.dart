/// Sort an owned list only when it is not already strictly ordered.
/// Equality deliberately uses List.sort too: skipping it could change the
/// existing tie order because List.sort does not promise a stable sort.
/// Callers still own deduplication, key snapshots and their domain comparator.
void sortIfNeeded<T>(List<T> values, Comparator<T> compare) {
  for (var index = 1; index < values.length; index++) {
    if (compare(values[index - 1], values[index]) >= 0) {
      values.sort(compare);
      return;
    }
  }
}

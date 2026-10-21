/// Pure visible-record metrics. No persistence, formatting or widget state.
/// Signed values are read once, preserving source addition order in each sum.
class ModelRecordExplorerMetrics {
  final num positive;
  final num negativeMagnitude;
  num get net => positive - negativeMagnitude;

  const ModelRecordExplorerMetrics._(this.positive, this.negativeMagnitude);

  static ModelRecordExplorerMetrics from<T>(
    Iterable<T> rows, {
    required num Function(T) valueOf,
    bool Function(T)? include,
  }) {
    num positive = 0;
    num negative = 0;
    for (final row in rows) {
      if (include != null && !include(row)) continue;
      final value = valueOf(row);
      if (value > 0) {
        positive += value;
      } else if (value < 0) {
        negative += value.abs();
      }
    }
    return ModelRecordExplorerMetrics._(positive, negative);
  }
}

import 'package:life_pilot/utils/const.dart';

/// Shared, immutable loading policy; no request or widget state belongs here.
class ModelEventLoadPolicy {
  static const memory = ModelEventLoadPolicy._(12, 3);
  static const standard = ModelEventLoadPolicy._(50, null);

  final int cloudPageSize;
  final int? previewBatchSize;

  const ModelEventLoadPolicy._(this.cloudPageSize, this.previewBatchSize);

  static ModelEventLoadPolicy forTable(String table) =>
      table == TableNames.memoryTrace ? memory : standard;
}

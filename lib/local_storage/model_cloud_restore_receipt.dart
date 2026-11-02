/// Fail closed before removing any local copy if the server receipt is invalid.
class CloudRestoreReceipt {
  const CloudRestoreReceipt(this.restored, this.omitted);
  final int restored;
  final int omitted;
  factory CloudRestoreReceipt.parse(
    Object? value, {
    required int expected,
    required bool allowOmission,
  }) {
    if (value is! Map) throw const FormatException('Invalid restore receipt');
    final restored = value['restored_count'];
    final omitted = value['omitted_answer_count'];
    final input = value['input_count'];
    if (restored is! int ||
        omitted is! int ||
        input is! int ||
        restored < 0 ||
        omitted < 0 ||
        input != expected ||
        restored + omitted != expected ||
        (!allowOmission && omitted > 0)) {
      throw const FormatException('Restore count mismatch');
    }
    return CloudRestoreReceipt(restored, omitted);
  }
}

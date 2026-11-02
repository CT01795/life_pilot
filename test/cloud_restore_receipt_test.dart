import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/local_storage/model_cloud_restore_receipt.dart';

void main() {
  test('restore receipt validates every input before local deletion', () {
    final receipt = CloudRestoreReceipt.parse(
      {'restored_count': 8, 'omitted_answer_count': 2, 'input_count': 10},
      expected: 10,
      allowOmission: true,
    );
    expect(receipt.restored, 8);
    expect(receipt.omitted, 2);
  });
  for (final receipt in <Object?>[
    null,
    10,
    {'restored_count': 8, 'omitted_answer_count': 1, 'input_count': 10},
    {'restored_count': 8, 'omitted_answer_count': 2, 'input_count': 11},
    {'restored_count': -1, 'omitted_answer_count': 11, 'input_count': 10},
    {'restored_count': '8', 'omitted_answer_count': 2, 'input_count': 10},
  ]) {
    test(
      'malformed restore receipt cannot authorize clearing local data: $receipt',
      () {
        expect(
          () => CloudRestoreReceipt.parse(
            receipt,
            expected: 10,
            allowOmission: true,
          ),
          throwsFormatException,
        );
      },
    );
  }
  test('omission requires explicit consent even with a complete receipt', () {
    expect(
      () => CloudRestoreReceipt.parse(
        {'restored_count': 8, 'omitted_answer_count': 2, 'input_count': 10},
        expected: 10,
        allowOmission: false,
      ),
      throwsFormatException,
    );
  });
}

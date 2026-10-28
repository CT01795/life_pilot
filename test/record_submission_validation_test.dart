import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/accounting/controller_accounting_detail.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/point_record/controller_point_record_detail.dart';
import 'package:life_pilot/point_record/service_point_record.dart';

void main() {
  test('accounting controller reports missing signs and remains reusable', () {
    final controller = ControllerAccountingDetail(
      service: ServiceAccounting(),
      auth: null,
      accountId: 'account',
    );
    addTearDown(controller.dispose);
    expect(
      () => controller.parseFromSpeech('午餐120', 'TWD', 1),
      throwsFormatException,
    );
    expect(controller.isLoading, isFalse);
    final rows = controller.parseFromSpeech('午餐-120.1234', 'TWD', 1);
    expect(rows.single.value, -120.1234);
    expect(rows.single.currency, 'TWD');
  });

  test('points controller never silently removes invalid fractional rows', () {
    final controller = ControllerPointRecordDetail(
      service: ServicePointRecord(),
      auth: null,
      accountId: 'points',
    );
    addTearDown(controller.dispose);
    expect(
      () => controller.parseFromSpeech('運動+10；遲到-2.5'),
      throwsFormatException,
    );
    expect(controller.isLoading, isFalse);
    expect(controller.parseFromSpeech('運動+10；遲到-2').map((r) => r.value), [
      10,
      -2,
    ]);
  });
}

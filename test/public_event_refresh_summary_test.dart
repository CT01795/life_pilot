import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/service_event_public.dart';

void main() {
  test('refresh requires at least half of attempted sources to succeed', () {
    expect(const PublicEventRefreshSummary.empty().hasSufficientSuccess, false);
    expect(
      const PublicEventRefreshSummary(
        attempted: 3,
        successful: 1,
        failed: 2,
      ).hasSufficientSuccess,
      false,
    );
    expect(
      const PublicEventRefreshSummary(
        attempted: 4,
        successful: 2,
        failed: 2,
      ).hasSufficientSuccess,
      true,
    );
    expect(
      const PublicEventRefreshSummary(
        attempted: 33,
        successful: 27,
        failed: 6,
      ).hasSufficientSuccess,
      true,
    );
  });
}

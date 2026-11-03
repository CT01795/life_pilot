import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/subscription_quota_presentation.dart';
import 'package:life_pilot/utils/decimal_input_formatter.dart';

void main() {
  for (final language in ['zh', 'en', 'ja', 'ko']) {
    test('$language groups subscription prices and quotas', () {
      final loc = lookupAppLocalizations(Locale(language));
      expect(loc.billingMonthlyPrice(12345), contains('12,345'));
      expect(loc.vendorQuarterlyPrice(12345), contains('12,345'));
      expect(
        loc.subscriptionUsage(1234, 5678),
        allOf(contains('1,234'), contains('5,678')),
      );
      expect(loc.subscriptionLocalUsage(1234), contains('1,234'));
      expect(
        loc.subscriptionOverageItem('Calendar', 12345, 10000, 2345),
        allOf(contains('12,345'), contains('10,000'), contains('2,345')),
      );
      expect(
        loc.dataUploadQuotaExceeded('Calendar', 12345, 2345, 10000),
        allOf(contains('12,345'), contains('2,345'), contains('10,000')),
      );
      expect(loc.adminSubscriptionActiveCount(1234), contains('1,234'));
      expect(subscriptionQuotaValue(loc, 'calendar_events', 12345), '12,345');
      expect(
        subscriptionQuotaValue(loc, 'image_bytes', 1234 << 20),
        '1,234 MB',
      );
    });
  }

  test(
    'admin numeric fields round-trip grouped input as a nonnegative integer',
    () {
      const formatter = GroupedIntegerInputFormatter();
      final formatted = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '12345',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(formatted.text, '12,345');
      expect(formatted.selection.end, 6);
      expect(GroupedIntegerInputFormatter.tryParse(formatted.text), 12345);
      expect(GroupedIntegerInputFormatter.tryParse('0'), 0);
      expect(
        formatter.formatEditUpdate(
          formatted,
          const TextEditingValue(text: '-1'),
        ),
        formatted,
      );
    },
  );
}

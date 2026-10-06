import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/widgets/widgets_adaptive_button.dart';

void main() {
  testWidgets('localized action buttons do not wrap or overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(260, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AdaptiveButtonBar(
              children: [
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const AdaptiveButtonLabel(
                    'Submit a recommended activity',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.list),
                  label: const AdaptiveButtonLabel(
                    'View all submitted attractions',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
    }

    final first = tester.getRect(find.byType(FilledButton));
    final second = tester.getRect(find.byType(OutlinedButton));
    expect(second.top, greaterThan(first.top));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/widgets_vendor_submission_hub.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

void main() {
  Future<void> pumpHub(
    WidgetTester tester, {
    required Locale locale,
    required double width,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: VendorSubmissionHub(
                submitLabel: locale.languageCode == 'ja'
                    ? '観光地を投稿'
                    : 'Submit attraction',
                showOnlyMySubmissions: false,
                onSubmit: () {},
                onFilterChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('uses short text actions on a narrow English phone header', (
    tester,
  ) async {
    await pumpHub(tester, locale: const Locale('en'), width: 220);

    expect(find.text('+ Submit'), findsOneWidget);
    expect(find.text('Mine'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses short text actions on a narrow Japanese phone header', (
    tester,
  ) async {
    await pumpHub(tester, locale: const Locale('ja'), width: 220);

    expect(find.text('+ \u6295\u7a3f'), findsOneWidget);
    expect(find.text('\u81ea\u5206'), findsOneWidget);
    expect(find.text('\u5168\u3066'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits beside search and more actions in a phone app bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: AppBar(
            titleSpacing: 4,
            title: VendorSubmissionHub(
              submitLabel: 'Submit attraction',
              showOnlyMySubmissions: false,
              onSubmit: () {},
              onFilterChanged: (_) {},
            ),
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
              PopupMenuButton<void>(itemBuilder: (_) => const []),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('action widths grow with text and labels stay on one line', (
    tester,
  ) async {
    await pumpHub(tester, locale: const Locale('en'), width: 420);

    final submitButton = find.widgetWithText(FilledButton, '+ Submit');
    expect(tester.getSize(submitButton).width, greaterThan(72));

    for (final label in ['+ Submit', 'Mine', 'All']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
    }
    expect(tester.takeException(), isNull);
  });
}

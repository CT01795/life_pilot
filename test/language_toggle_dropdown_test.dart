import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:life_pilot/utils/widgets/widgets_language_toggle_dropdown.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('compact language menu keeps every option on one row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ProviderLocale(locale: const Locale('en')),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(
              actions: const [LanguageToggleDropdown(compact: true)],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.language));
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuItem<Locale>), findsNWidgets(4));
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      if (text.data case final label? when label.isNotEmpty) {
        expect(text.maxLines, 1);
        expect(text.softWrap, isFalse);
      }
    }
    expect(tester.takeException(), isNull);
  });
}

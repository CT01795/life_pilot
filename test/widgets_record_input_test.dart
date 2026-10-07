import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/widgets/widgets_record_input.dart';

void main() {
  testWidgets('record date and time controls fit compact screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WidgetsRecordDateTimePicker(
            value: DateTime(2026, 10, 7, 14, 30),
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    expect(find.byIcon(Icons.access_time), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/widgets_calendar.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

void main() {
  Future<void> pumpCalendarBar(
    WidgetTester tester, {
    required double width,
  }) async {
    tester.view.physicalSize = Size(width, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ControllerAuth(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CalendarAppBar(
              monthLabel: '2026/10',
              monthColor: Colors.blue,
              onPrevious: () {},
              onNext: () {},
              onToday: () {},
              onAdd: () {},
              onSharing: () {},
              onMonthTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('calendar actions remain large and fit a phone width', (
    tester,
  ) async {
    await pumpCalendarBar(tester, width: 360);

    expect(
      tester.widget<Icon>(find.byIcon(Icons.people_alt_outlined)).size,
      32,
    );
    expect(tester.widget<Icon>(find.byIcon(Icons.today)).size, 32);
    expect(tester.widget<Icon>(find.byIcon(Icons.add)).size, 32);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar actions use tablet-sized icons on wide screens', (
    tester,
  ) async {
    await pumpCalendarBar(tester, width: 800);

    expect(
      tester.widget<Icon>(find.byIcon(Icons.people_alt_outlined)).size,
      42,
    );
    expect(tester.widget<Icon>(find.byIcon(Icons.today)).size, 42);
    expect(tester.widget<Icon>(find.byIcon(Icons.add)).size, 42);
    expect(tester.takeException(), isNull);
  });
}

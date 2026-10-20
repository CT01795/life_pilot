import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/controller_dashboard.dart';
import 'package:life_pilot/pages/home/repository/repository_dashboard.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/today_life_overview_card.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('home overview fits a narrow phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final localeProvider = ProviderLocale(locale: const Locale('en'));
    final dashboard = ControllerDashboard(
      repository: DashboardRepository(),
      localeProvider: localeProvider,
    );
    addTearDown(dashboard.dispose);
    addTearDown(localeProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: localeProvider),
          ChangeNotifierProvider.value(value: dashboard),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: TodayLifeOverviewCard(
                  showPoints: true,
                  onSchedulePressed: _noop,
                  onAccountingPressed: _noop,
                  onPointsPressed: _noop,
                  onAccountingQuickAdd: _noop,
                  onPointsQuickAdd: _noop,
                  onDiscoverEvents: _noop,
                  onDiscoverPlaces: _noop,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

void _noop() {}

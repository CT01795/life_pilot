import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_city.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_city_selector.dart';

void main() {
  Widget buildSelector({
    bool isLoading = false,
    required DashboardCityChanged onChanged,
  }) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: DashboardCitySelector(
        selectedCity: 'Taipei',
        cities: const [
          DashboardCity(name: 'Taipei', count: 3),
          DashboardCity(name: 'Taichung', count: 2),
        ],
        isLoading: isLoading,
        onChanged: onChanged,
      ),
    ),
  );

  testWidgets('returns a different selected city', (tester) async {
    String? selectedCity;
    await tester.pumpWidget(
      buildSelector(onChanged: (city) async => selectedCity = city),
    );

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taichung'));
    await tester.pumpAndSettle();

    expect(selectedCity, 'Taichung');
    expect(tester.takeException(), isNull);
  });

  testWidgets('disables selection while the section is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSelector(isLoading: true, onChanged: (_) async {}),
    );

    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

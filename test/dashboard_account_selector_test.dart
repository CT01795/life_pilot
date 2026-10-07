import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_account_selector.dart';

void main() {
  Widget buildSelector({
    String? selectedAccountId,
    String? selectedAccountName,
    required DashboardAccountLoader loadAccounts,
    required DashboardAccountChanged onChanged,
  }) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 280,
        child: DashboardAccountSelector(
          icon: Icons.account_balance_wallet,
          selectedAccountId: selectedAccountId,
          selectedAccountName: selectedAccountName,
          loadAccounts: loadAccounts,
          onChanged: onChanged,
          onOpenAccountPage: () {},
          accountPageLabel: 'Accounts',
        ),
      ),
    ),
  );

  testWidgets('returns the selected account', (tester) async {
    DashboardAccountOption? selected;
    await tester.pumpWidget(
      buildSelector(
        loadAccounts: () async => const [
          DashboardAccountOption(
            id: 'trip-id',
            name: 'Trip wallet',
            category: 'project',
          ),
        ],
        onChanged: (value) async => selected = value,
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Journey'), findsOneWidget);

    await tester.tap(find.text('Trip wallet'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(selected?.id, 'trip-id');
    expect(selected?.name, 'Trip wallet');
    expect(tester.takeException(), isNull);
  });

  testWidgets('distinguishes clearing from cancelling the dialog', (
    tester,
  ) async {
    var callbackCount = 0;
    const existing = DashboardAccountOption(
      id: 'existing-id',
      name: 'Existing account',
      category: 'personal',
    );
    DashboardAccountOption? selected = existing;
    await tester.pumpWidget(
      buildSelector(
        selectedAccountId: existing.id,
        selectedAccountName: existing.name,
        loadAccounts: () async => const [existing],
        onChanged: (value) async {
          callbackCount++;
          selected = value;
        },
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Clear'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(callbackCount, 1);
    expect(selected, isNull);
    expect(tester.takeException(), isNull);
  });
}

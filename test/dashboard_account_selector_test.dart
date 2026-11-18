import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_account_selector.dart';
import 'package:life_pilot/utils/widgets/widgets_load_more.dart';

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
        loadAccounts: ({required search, cursor, selectedId}) async =>
            const DashboardAccountOptionPage(
              rows: [
                DashboardAccountOption(
                  id: 'trip-id',
                  name: 'Trip wallet',
                  category: 'project',
                ),
              ],
              nextCursor: null,
            ),
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
        loadAccounts: ({required search, cursor, selectedId}) async =>
            const DashboardAccountOptionPage(
              rows: [existing],
              nextCursor: null,
            ),
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

  testWidgets('passes selected id, cursor and search to the page loader', (
    tester,
  ) async {
    final requests =
        <({String search, Map<String, dynamic>? cursor, String? selectedId})>[];
    await tester.pumpWidget(
      buildSelector(
        selectedAccountId: 'selected-id',
        selectedAccountName: 'Selected account',
        loadAccounts: ({required search, cursor, selectedId}) async {
          requests.add((
            search: search,
            cursor: cursor,
            selectedId: selectedId,
          ));
          if (search.isNotEmpty) {
            return const DashboardAccountOptionPage(
              rows: [
                DashboardAccountOption(
                  id: 'search-id',
                  name: 'Search result',
                  category: 'personal',
                ),
              ],
              nextCursor: null,
            );
          }
          if (cursor != null) {
            return const DashboardAccountOptionPage(
              rows: [
                DashboardAccountOption(
                  id: 'second-id',
                  name: 'Second account',
                  category: 'project',
                ),
              ],
              nextCursor: null,
            );
          }
          return const DashboardAccountOptionPage(
            rows: [
              DashboardAccountOption(
                id: 'first-id',
                name: 'First account',
                category: 'personal',
              ),
            ],
            nextCursor: {'id': 'next'},
          );
        },
        onChanged: (_) async {},
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pump(const Duration(milliseconds: 400));
    expect(requests.single.selectedId, 'selected-id');

    final loadMore = find.descendant(
      of: find.byType(WidgetsLoadMore),
      matching: find.byType(TextButton),
    );
    tester.widget<TextButton>(loadMore).onPressed!();
    await tester.pump();
    await tester.pump();
    expect(requests[1].cursor, {'id': 'next'});
    expect(find.text('Second account'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'needle');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump();
    expect(requests.last.search, 'needle');
    expect(requests.last.cursor, isNull);
    expect(requests.last.selectedId, 'selected-id');
    expect(find.text('Search result'), findsOneWidget);
    expect(find.text('First account'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

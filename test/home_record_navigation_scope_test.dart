import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/page_accounting_detail.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/pages/home/controller_dashboard.dart';
import 'package:life_pilot/pages/home/repository/repository_dashboard.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/home_quick_record_navigation.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/page_point_record_detail.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/provider_locale.dart';

class _Auth extends ControllerAuth {
  String? owner = 'a@example.com';
  DataStorageLocation storage = DataStorageLocation.cloud;
  int revision = 0;
  @override
  String? get currentAccount => owner;
  @override
  DataStorageLocation get preferredStorage => storage;
  @override
  int get personalDataRevision => revision;
}

class _Accounting extends ServiceAccounting {
  final pending = Completer<List<ModelAccountingAccount>>();
  @override
  Future<ModelAccountingAccount?> fetchAccountById({
    required String user,
    required String accountId,
  }) async {
    expect(user, 'a@example.com');
    expect(accountId, 'selected');
    return (await pending.future).where((a) => a.id == accountId).firstOrNull;
  }

  @override
  Future<List<ModelAccountingAccount>> fetchAccounts({
    required String user,
    String? category,
    int? projectLimit,
    bool includeGraph = true,
  }) {
    expect(user, 'a@example.com');
    expect(includeGraph, false);
    return pending.future;
  }
}

class _Points extends ServicePointRecord {
  final pending = Completer<List<ModelPointRecordAccount>>();
  @override
  Future<ModelPointRecordAccount?> fetchAccountById({
    required String user,
    required String accountId,
  }) async {
    expect(user, 'a@example.com');
    expect(accountId, 'selected');
    return (await pending.future).where((a) => a.id == accountId).firstOrNull;
  }

  @override
  Future<List<ModelPointRecordAccount>> fetchAccounts({
    required String user,
    String? category,
    int? projectLimit,
    bool includeGraph = true,
  }) {
    expect(user, 'a@example.com');
    expect(includeGraph, false);
    return pending.future;
  }
}

class _Dashboard extends ControllerDashboard {
  _Dashboard(ProviderLocale locale)
    : super(repository: DashboardRepository(), localeProvider: locale);
  int refreshed = 0;
  @override
  Future<void> refreshAccounting({required String accountId}) async {
    refreshed++;
  }

  @override
  Future<void> refreshPoints({required String accountId}) async {
    refreshed++;
  }
}

// Record route requests without building real detail pages or loading their DB.
class _RecordingNavigator extends Navigator {
  const _RecordingNavigator({
    required super.key,
    required super.onGenerateRoute,
  });
  @override
  NavigatorState createState() => _RecordingNavigatorState();
}

class _RecordingNavigatorState extends NavigatorState {
  final requested = <Route<dynamic>>[];
  final result = Completer<bool?>();
  @override
  Future<T?> push<T extends Object?>(Route<T> route) {
    requested.add(route);
    return result.future.then((value) => value as T?);
  }
}

class _Fixture {
  _Fixture() {
    view = ModelAuthView(auth);
    dashboard = _Dashboard(locale);
    dashboard.setting
      ..accountingAccountId = 'selected'
      ..accountingAccountName = 'Selected'
      ..pointAccountId = 'selected'
      ..pointAccountName = 'Selected';
  }
  final auth = _Auth();
  final locale = ProviderLocale(locale: const Locale('en'));
  late final ModelAuthView view;
  late final _Dashboard dashboard;
  final accounting = _Accounting();
  final points = _Points();
  final navigation = GlobalKey<_RecordingNavigatorState>();
  late BuildContext context;
  Future<void>? operation;

  Widget app({required bool isPoints, required bool quick}) => MultiProvider(
    providers: [
      ChangeNotifierProvider<ModelAuthView>.value(value: view),
      ChangeNotifierProvider<ControllerDashboard>.value(value: dashboard),
      Provider<ServiceAccounting>.value(value: accounting),
      Provider<ServicePointRecord>.value(value: points),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _RecordingNavigator(
        key: navigation,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (ctx) {
            context = ctx;
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  operation = isPoints
                      ? (quick
                            ? openHomePointQuickAdd(ctx)
                            : openHomePointDetails(ctx))
                      : (quick
                            ? openHomeAccountingQuickAdd(ctx)
                            : openHomeAccountingDetails(ctx));
                  unawaited(operation);
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    ),
  );

  void complete({bool empty = false}) {
    accounting.pending.complete(
      empty
          ? []
          : [
              ModelAccountingAccount(
                id: 'other',
                accountName: 'Other',
                category: 'personal',
              ),
              ModelAccountingAccount(
                id: 'selected',
                accountName: 'Selected',
                category: 'personal',
              ),
            ],
    );
    points.pending.complete(
      empty
          ? []
          : [
              ModelPointRecordAccount(
                id: 'other',
                accountName: 'Other',
                category: 'personal',
              ),
              ModelPointRecordAccount(
                id: 'selected',
                accountName: 'Selected',
                category: 'personal',
              ),
            ],
    );
  }

  void dispose() {
    view.dispose();
    auth.dispose();
    if (!dashboard.notifierDisposed) dashboard.dispose();
    locale.dispose();
  }
}

void main() {
  for (final isPoints in [false, true]) {
    for (final quick in [false, true]) {
      for (final change in [
        'owner',
        'storage',
        'revision',
        'selection',
        'disposed',
        'unmounted',
      ]) {
        testWidgets(
          '$isPoints/$quick: $change discards a late account result',
          (tester) async {
            final f = _Fixture();
            addTearDown(f.dispose);
            await tester.pumpWidget(f.app(isPoints: isPoints, quick: quick));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Open'));
            final navigator = f.navigation.currentState!;
            switch (change) {
              case 'owner':
                f.auth.owner = 'b@example.com';
              case 'storage':
                f.auth.storage = DataStorageLocation.local;
              case 'revision':
                f.auth.revision++;
              case 'selection':
                f.dashboard.setting.accountingAccountId = 'changed';
                f.dashboard.setting.pointAccountId = 'changed';
              case 'disposed':
                f.dashboard.dispose();
              case 'unmounted':
                await tester.pumpWidget(const SizedBox());
            }
            f.complete();
            await tester.pump();
            await f.operation;
            expect(navigator.requested, isEmpty);
            expect(f.dashboard.refreshed, 0);
            expect(tester.takeException(), null);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }

      testWidgets('$isPoints/$quick: missing account never opens a detail', (
        tester,
      ) async {
        final f = _Fixture();
        addTearDown(f.dispose);
        await tester.pumpWidget(f.app(isPoints: isPoints, quick: quick));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        f.complete(empty: true);
        await tester.pump();
        await f.operation;
        expect(f.navigation.currentState!.requested, isEmpty);
        expect(find.byType(SnackBar), quick ? findsOneWidget : findsNothing);
        expect(f.dashboard.refreshed, 0);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets(
        '$isPoints/$quick: unchanged scope opens the selected detail',
        (tester) async {
          final f = _Fixture();
          addTearDown(f.dispose);
          await tester.pumpWidget(f.app(isPoints: isPoints, quick: quick));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Open'));
          f.complete();
          await tester.pump();
          final navigator = f.navigation.currentState!;
          final route = navigator.requested.single as MaterialPageRoute<bool>;
          final page = route.builder(f.context);
          if (isPoints) {
            expect((page as PagePointRecordDetail).account.id, 'selected');
            expect(page.returnAfterSubmit, quick);
          } else {
            expect((page as PageAccountingDetail).account.id, 'selected');
            expect(page.returnAfterSubmit, quick);
          }
          navigator.result.complete(true);
          await tester.pump();
          await f.operation;
          expect(f.dashboard.refreshed, quick ? 1 : 0);
          route.dispose();
          await tester.pumpWidget(const SizedBox());
        },
      );
    }

    testWidgets(
      '$isPoints: saving after scope change cannot refresh old account',
      (tester) async {
        final f = _Fixture();
        addTearDown(f.dispose);
        await tester.pumpWidget(f.app(isPoints: isPoints, quick: true));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        f.complete();
        await tester.pump();
        final navigator = f.navigation.currentState!;
        expect(navigator.requested, hasLength(1));
        f.auth.revision++;
        navigator.result.complete(true);
        await tester.pump();
        await f.operation;
        expect(f.dashboard.refreshed, 0);
        (navigator.requested.single as MaterialPageRoute<bool>).dispose();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

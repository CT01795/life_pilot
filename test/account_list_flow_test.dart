import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/accounting/accounting_account_navigation.dart';
import 'package:life_pilot/accounting/controller_accounting_list.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/point_record/controller_point_record_list.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/point_record_account_navigation.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/utils/widgets/widgets_account_name_dialog.dart';

class _Auth extends ControllerAuth {
  String account = 'a@example.com';
  DataStorageLocation storage = DataStorageLocation.cloud;
  @override
  String get currentAccount => account;
  @override
  DataStorageLocation get preferredStorage => storage;
  void switchAccount() {
    account = 'b@example.com';
    notifyListeners();
  }

  void switchStorage() {
    storage = DataStorageLocation.local;
    notifyListeners();
  }
}

class _Requests {
  int creates = 0;
  final categories = <String>[];
  final pending = <Completer<List<String>>>[];
  bool immediate = false;
  void Function()? onFetch;
  Future<List<String>> fetch(String? category) {
    categories.add(category!);
    onFetch?.call();
    if (immediate) return Future.value(['$category account']);
    final request = Completer<List<String>>();
    pending.add(request);
    return request.future;
  }
}

class _Accounting extends ServiceAccounting {
  _Accounting(this.requests);
  final _Requests requests;
  Completer<String>? pendingCurrency;
  int creates = 0;
  @override
  Future<List<ModelAccountingAccount>> fetchAccounts({
    required String user,
    String? category,
    int? projectLimit,
    bool includeGraph = true,
  }) async => (await requests.fetch(category))
      .map(
        (id) => ModelAccountingAccount(
          id: id,
          accountName: id,
          category: category!,
          currency: 'TWD',
        ),
      )
      .toList();
  @override
  Future<ModelAccountingAccount?> findAccountByEventId({
    required String eventId,
    required String user,
  }) async => null;
  @override
  Future<String> fetchLatestAccount({
    required String user,
    required String category,
  }) async => pendingCurrency == null ? 'TWD' : pendingCurrency!.future;
  @override
  Future<ModelAccountingAccount> createAccount({
    required String name,
    required String user,
    required String? currency,
    required String category,
    String? eventId,
  }) async {
    creates++;
    requests.creates++;
    return ModelAccountingAccount(
      id: 'new',
      accountName: name,
      category: category,
    );
  }
}

class _Points extends ServicePointRecord {
  _Points(this.requests);
  final _Requests requests;
  @override
  Future<List<ModelPointRecordAccount>> fetchAccounts({
    required String user,
    String? category,
    int? projectLimit,
    bool includeGraph = true,
  }) async => (await requests.fetch(category))
      .map(
        (id) => ModelPointRecordAccount(
          id: id,
          accountName: id,
          category: category!,
        ),
      )
      .toList();
  @override
  Future<ModelPointRecordAccount?> findAccountByEventId({
    required String eventId,
    required String user,
  }) async => null;

  @override
  Future<ModelPointRecordAccount> createAccount({
    required String name,
    required String user,
    required String? currency,
    required String category,
    String? eventId,
  }) async {
    requests.creates++;
    return ModelPointRecordAccount(
      id: 'new',
      accountName: name,
      category: category,
    );
  }
}

/// Identical contract tests for both account controllers, without dynamic calls.
class _Harness {
  _Harness.accounting(ControllerAccountingList c)
    : controller = c,
      load = c.loadAccounts,
      select = c.setCategory,
      ids = (() => c.accounts.map((a) => a.id).toList()),
      loading = (() => c.isLoading),
      error = (() => c.loadError);
  _Harness.points(ControllerPointRecordList c)
    : controller = c,
      load = c.loadAccounts,
      select = c.setCategory,
      ids = (() => c.accounts.map((a) => a.id).toList()),
      loading = (() => c.isLoading),
      error = (() => c.loadError);
  final SafeChangeNotifier controller;
  final Future<void> Function({String? inputCategory}) load;
  final Future<void> Function(String) select;
  final List<String> Function() ids;
  final bool Function() loading;
  final Object? Function() error;
}

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  for (final accounting in [true, false]) {
    group(accounting ? 'accounting' : 'points', () {
      late _Auth auth;
      late _Requests requests;
      late _Harness h;
      setUp(() {
        auth = _Auth();
        requests = _Requests();
        h = accounting
            ? _Harness.accounting(
                ControllerAccountingList(
                  service: _Accounting(requests),
                  auth: auth,
                ),
              )
            : _Harness.points(
                ControllerPointRecordList(
                  service: _Points(requests),
                  auth: auth,
                ),
              );
      });
      tearDown(() {
        if (!h.controller.notifierDisposed) h.controller.dispose();
        auth.dispose();
      });

      test('same category shares the active request', () async {
        final first = h.load();
        final second = h.load();
        expect(identical(first, second), isTrue);
        expect(requests.categories, ['personal']);
        requests.pending.single.complete(['personal']);
        await Future.wait([first, second]);
        expect(h.ids(), ['personal']);
      });

      test('synchronous service re-entry awaits the actual request', () async {
        Future<void>? joined;
        requests.onFetch = () {
          joined = h.load();
        };
        final first = h.load();
        expect(joined, same(first));
        var completed = false;
        unawaited(joined!.then((_) => completed = true));
        await Future<void>.delayed(Duration.zero);
        expect(completed, isFalse);
        requests.pending.single.complete(['personal']);
        await first;
        expect(completed, isTrue);
        expect(h.ids(), ['personal']);
      });

      test(
        'account change during loading notification returns safely',
        () async {
          var switched = false;
          h.controller.addListener(() {
            if (!switched && h.loading()) {
              switched = true;
              auth.switchAccount();
            }
          });
          final first = h.load();
          requests.pending.single.complete(['old account']);
          await first;
          expect(h.ids(), isEmpty);
          expect(h.loading(), isFalse);
        },
      );

      test(
        'new category wins even when the previous response arrives last',
        () async {
          final first = h.select('personal');
          final second = h.select('project');
          expect(requests.categories, ['personal', 'project']);
          requests.pending[1].complete(['project']);
          await second;
          requests.pending[0].complete(['personal']);
          await first;
          expect(h.ids(), ['project']);
          expect(h.loading(), isFalse);
        },
      );

      test(
        'old category failure does not replace new category state',
        () async {
          final first = h.select('personal');
          final second = h.select('project');
          requests.pending[0].completeError(StateError('old failure'));
          await first;
          expect(h.loading(), isTrue);
          expect(h.error(), isNull);
          requests.pending[1].complete(['project']);
          await second;
          expect(h.ids(), ['project']);
        },
      );

      test(
        'account change clears data and ignores late response without proxy update',
        () async {
          requests.immediate = true;
          await h.load();
          requests.immediate = false;
          final pending = h.load();
          auth.switchAccount();
          expect(h.ids(), isEmpty);
          requests.pending.single.complete(['old']);
          await pending;
          expect(h.ids(), isEmpty);
          expect(h.loading(), isFalse);
        },
      );

      test('storage switch invalidates a pending query', () async {
        final pending = h.load();
        auth.switchStorage();
        requests.pending.single.complete(['cloud']);
        await pending;
        expect(h.ids(), isEmpty);
        expect(h.loading(), isFalse);
      });

      test('disposal prevents late data mutation', () async {
        final pending = h.load();
        h.controller.dispose();
        requests.pending.single.complete(['late']);
        await pending;
        expect(h.ids(), isEmpty);
      });

      testWidgets(
        'picker categories are isolated from each other and the parent',
        (tester) async {
          requests.immediate = true;
          if (accounting) {
            final controller = h.controller as ControllerAccountingList;
            await tester.pumpWidget(
              Provider<ServiceAccounting>.value(
                value: _Accounting(requests),
                child: _app(
                  Builder(
                    builder: (context) => TextButton(
                      onPressed: () => controller.handleAccounting(
                        context: context,
                        eventId: 'event',
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            );
          } else {
            final controller = h.controller as ControllerPointRecordList;
            await tester.pumpWidget(
              Provider<ServicePointRecord>.value(
                value: _Points(requests),
                child: _app(
                  Builder(
                    builder: (context) => TextButton(
                      onPressed: () => controller.handlePointRecord(
                        context: context,
                        eventId: 'event',
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            );
          }
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(find.text('personal account'), findsOneWidget);
          await tester.tap(find.byType(Tab).last);
          await tester.pumpAndSettle();
          expect(find.text('project account'), findsOneWidget);
          await tester.tap(find.byType(Tab).first);
          await tester.pumpAndSettle();
          expect(find.text('personal account'), findsOneWidget);
          expect(h.ids(), isEmpty);
          // Creating in the isolated picker also refreshes the parent list.
          await tester.tap(find.widgetWithIcon(TextButton, Icons.add));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'New account');
          await tester.pump();
          await tester.tap(find.byType(ElevatedButton));
          await tester.pumpAndSettle();
          expect(requests.creates, 1);
          expect(h.ids(), ['personal account']);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    });
  }

  test(
    'currency completion cannot create an account under a switched user',
    () async {
      final auth = _Auth();
      final service = _Accounting(_Requests())
        ..pendingCurrency = Completer<String>();
      final controller = ControllerAccountingList(service: service, auth: auth);
      final creation = controller.createAccount(name: 'name');
      final check = expectLater(creation, throwsStateError);
      auth.switchAccount();
      service.pendingCurrency!.complete('USD');
      await check;
      expect(service.creates, 0);
      expect(controller.mainCurrency, isNull);
      controller.dispose();
      auth.dispose();
    },
  );

  testWidgets('name dialog rejects whitespace and returns trimmed input', (
    tester,
  ) async {
    String? name;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              name = await showDialog<String>(
                context: context,
                builder: (_) => const WidgetsAccountNameDialog(),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), '  Trip  ');
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(name, 'Trip');
    expect(tester.takeException(), isNull);
  });
}

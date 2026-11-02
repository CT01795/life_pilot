import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/subscription/service_subscription.dart';
import 'package:life_pilot/subscription/widgets_subscription_cleanup.dart';

class _Auth extends ControllerAuth {
  String account = 'one@example.com';
  DataStorageLocation storage = DataStorageLocation.cloud;
  bool admin = true;
  int refreshed = 0;
  @override
  String get currentAccount => account;
  @override
  DataStorageLocation get preferredStorage => storage;
  @override
  bool get isSysAdmin => admin;
  @override
  Future<void> refreshAfterPersonalDataCleanup() async {
    refreshed++;
  }
}

class _Service extends ServiceSubscription {
  Completer<List<SubscriptionCleanupPreview>>? pending;
  int previews = 0, cleanups = 0;
  @override
  Future<List<SubscriptionCleanupPreview>> fetchCleanupPreview({
    String? email,
  }) async {
    previews++;
    return pending?.future ?? [];
  }

  @override
  Future<Map<String, dynamic>> cleanupData({
    String? email,
    required String mode,
  }) async {
    cleanups++;
    return {};
  }
}

void main() {
  late _Auth auth;
  late _Service service;
  Future<AppLocalizations> mount(WidgetTester tester) async {
    auth = _Auth();
    service = _Service();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ControllerAuth>.value(
        value: auth,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SubscriptionDataCleanup(service: service)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(SubscriptionDataCleanup)),
    )!;
  }

  testWidgets('confirmed same-scope cleanup executes once and refreshes', (
    tester,
  ) async {
    final loc = await mount(tester);
    await tester.tap(find.text(loc.dataCleanupAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(loc.dataCleanupAll));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(loc.confirm));
    await tester.pumpAndSettle();
    expect(service.previews, 1);
    expect(service.cleanups, 1);
    expect(auth.refreshed, 1);
  });
  for (final change in ['account', 'storage', 'role']) {
    for (final stage in ['preview', 'confirmation']) {
      testWidgets('$change changed during $stage never clears another scope', (
        tester,
      ) async {
        final loc = await mount(tester);
        if (stage == 'preview') {
          service.pending = Completer<List<SubscriptionCleanupPreview>>();
        }
        await tester.tap(find.text(loc.dataCleanupAction));
        if (stage == 'preview') {
          await tester.pump();
        } else {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.tap(find.text(loc.dataCleanupAll));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        }
        switch (change) {
          case 'account':
            auth.account = 'two@example.com';
          case 'storage':
            auth.storage = DataStorageLocation.local;
          case 'role':
            auth.admin = false;
        }
        if (stage == 'preview') {
          service.pending!.complete([]);
        } else {
          await tester.tap(find.text(loc.confirm));
        }
        await tester.pumpAndSettle();
        expect(service.cleanups, 0);
        expect(auth.refreshed, 0);
        expect(find.byType(AlertDialog), findsNothing);
      });
    }
  }
}

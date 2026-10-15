import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/apps/controller_module_authorization.dart';
import 'package:life_pilot/apps/page_module_authorization.dart';
import 'package:life_pilot/apps/service_module.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Service extends ServiceModule {
  final modules = <String, List<String>>{
    'a@example.com': ['game'],
    'b@example.com': ['stock'],
  };
  int reads = 0;
  final writes = <(String, Set<String>)>[];
  bool writeBack = true;
  Object? failure;
  Completer<List<String>>? pending;
  Completer<void>? pendingSave;

  @override
  Future<List<String>> loadUserModulesAsAdmin(String account) async {
    reads++;
    if (failure != null) throw failure!;
    if (pending != null) return pending!.future;
    if (!modules.containsKey(account)) {
      throw const PostgrestException(message: 'not found', code: 'P0002');
    }
    return modules[account]!;
  }

  @override
  Future<void> saveUserModulesAsAdmin({
    required String account,
    required Iterable<String> moduleKeys,
  }) async {
    writes.add((account, moduleKeys.toSet()));
    if (pendingSave != null) await pendingSave!.future;
    if (writeBack) modules[account] = moduleKeys.toList();
  }
}

class _Auth extends ControllerAuth {
  @override
  bool get isSysAdmin => true;
}

void main() {
  test('empty or unsearched account cannot be saved', () async {
    final service = _Service();
    final c = ControllerModuleAuthorization(service: service);
    addTearDown(c.dispose);
    expect(await c.search(' '), ModuleAuthorizationResult.searchFirst);
    expect(await c.save(), ModuleAuthorizationResult.searchFirst);
    expect(service.reads, 0);
    expect(service.writes, isEmpty);
  });
  test(
    'normalizes searched account, saves snapshot, and verifies returned modules',
    () async {
      final service = _Service();
      final c = ControllerModuleAuthorization(service: service);
      addTearDown(c.dispose);
      expect(
        await c.search(' A@EXAMPLE.COM '),
        ModuleAuthorizationResult.loaded,
      );
      c.setSelected('game', false);
      c.setSelected('stock', true);
      expect(await c.save(), ModuleAuthorizationResult.saved);
      expect(service.writes.single.$1, 'a@example.com');
      expect(service.writes.single.$2, {'stock'});
      expect(service.reads, 2);
      expect(c.isLoading, false);
      expect(() => c.selectedKeys.add('game'), throwsUnsupportedError);
    },
  );
  test(
    'changing email invalidates selections and requires a fresh lookup',
    () async {
      final service = _Service();
      final c = ControllerModuleAuthorization(service: service);
      addTearDown(c.dispose);
      await c.search('a@example.com');
      c.setEmail('b@example.com');
      expect(c.hasSearched, false);
      expect(c.selectedKeys, isEmpty);
      expect(await c.save(), ModuleAuthorizationResult.searchFirst);
      expect(service.writes, isEmpty);
      await c.search('b@example.com');
      expect(c.selectedKeys, {'stock'});
    },
  );
  test(
    'missing user and undeployed RPC do not reveal an editable list',
    () async {
      final service = _Service();
      final c = ControllerModuleAuthorization(service: service);
      addTearDown(c.dispose);
      expect(
        await c.search('missing@example.com'),
        ModuleAuthorizationResult.userNotFound,
      );
      expect(c.hasSearched, false);
      service.failure = const PostgrestException(
        message: 'RPC missing',
        code: 'PGRST202',
      );
      expect(
        await c.search('a@example.com'),
        ModuleAuthorizationResult.notDeployed,
      );
      expect(c.selectedKeys, isEmpty);
      expect(c.isLoading, false);
    },
  );
  test('save mismatch reports failure rather than false success', () async {
    final service = _Service()..writeBack = false;
    final c = ControllerModuleAuthorization(service: service);
    addTearDown(c.dispose);
    await c.search('a@example.com');
    c.setSelected('stock', true);
    expect(await c.save(), ModuleAuthorizationResult.saveFailed);
    expect(c.selectedKeys, {'game', 'stock'});
    expect(c.isLoading, false);
  });
  test('duplicate searches and saves are suppressed', () async {
    final service = _Service()..pending = Completer<List<String>>();
    final c = ControllerModuleAuthorization(service: service);
    addTearDown(c.dispose);
    final search = c.search('a@example.com');
    expect(await c.search('a@example.com'), isNull);
    service.pending!.complete(['game']);
    await search;
    service.pending = null;
    service.pendingSave = Completer<void>();
    final save = c.save();
    expect(await c.save(), isNull);
    c.setSelected('stock', true);
    service.pendingSave!.complete();
    expect(await save, ModuleAuthorizationResult.saved);
    expect(service.writes.length, 1);
    expect(c.selectedKeys, {'game'});
  });
  test('stale lookup cannot replace the next account permissions', () async {
    final service = _Service()..pending = Completer<List<String>>();
    final c = ControllerModuleAuthorization(service: service);
    addTearDown(c.dispose);
    final pending = service.pending!;
    final old = c.search('a@example.com');
    c.setEmail('b@example.com');
    service.pending = null;
    await c.search('b@example.com');
    pending.complete(['game']);
    expect(await old, isNull);
    expect(c.selectedKeys, {'stock'});
  });
  test('dispose discards a late lookup result', () async {
    final service = _Service()..pending = Completer<List<String>>();
    final c = ControllerModuleAuthorization(service: service);
    final request = c.search('a@example.com');
    c.dispose();
    service.pending!.complete(['game']);
    expect(await request, isNull);
    expect(c.hasSearched, false);
  });
  testWidgets('editing searched email hides old account checkboxes', (
    tester,
  ) async {
    final service = _Service();
    await tester.pumpWidget(
      ChangeNotifierProvider<ControllerAuth>(
        create: (_) => _Auth(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PageModuleAuthorization(service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a@example.com');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsWidgets);
    await tester.enterText(find.byType(TextField), 'b@example.com');
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(service.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

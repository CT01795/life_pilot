import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/game_exit_guard.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

Future<void> _openGame(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => GameExitGuard(
                  child: Builder(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () => Navigator.maybePop(context),
                        child: const Text('Back from game'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('Open game'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open game'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('confirm leaves game and returns to previous page', (
    tester,
  ) async {
    await _openGame(tester);
    await tester.tap(find.text('Back from game'));
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(tester.element(find.byType(AlertDialog)))!;
    await tester.tap(find.widgetWithText(FilledButton, loc.confirm));
    await tester.pumpAndSettle();
    expect(find.text('Open game'), findsOneWidget);
    expect(find.text('Back from game'), findsNothing);
  });
  testWidgets('cancel keeps game and a later confirm still leaves', (
    tester,
  ) async {
    await _openGame(tester);
    await tester.tap(find.text('Back from game'));
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(tester.element(find.byType(AlertDialog)))!;
    await tester.tap(find.widgetWithText(TextButton, loc.cancel));
    await tester.pumpAndSettle();
    expect(find.text('Back from game'), findsOneWidget);
    await tester.tap(find.text('Back from game'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, loc.confirm));
    await tester.pumpAndSettle();
    expect(find.text('Open game'), findsOneWidget);
  });
}

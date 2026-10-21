import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/widgets/widgets_record_preview_tile.dart';

void main() {
  for (final language in ['zh', 'en', 'ja', 'ko']) {
    for (final points in [false, true]) {
      testWidgets(
        '$language points=$points: editable confirmation rows show hover hint but actions do not',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var edits = 0;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) {
                          final loc = AppLocalizations.of(context)!;
                          return AlertDialog(
                            scrollable: true,
                            title: Text(loc.recordPleaseConfirm),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final value in ['-23.4', '+100'])
                                  WidgetsRecordPreviewTile(
                                    title: Text(
                                      points ? '$value points' : '$value TWD',
                                    ),
                                    subtitle: const Text(
                                      'Category\n2026/10/21 12:30',
                                    ),
                                    onTap: () => edits++,
                                  ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(loc.cancel),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(loc.confirm),
                              ),
                            ],
                          );
                        },
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final loc = AppLocalizations.of(
            tester.element(find.byType(AlertDialog)),
          )!;
          expect(find.byTooltip(loc.tapToEditRecordHint), findsNWidgets(2));
          for (final button in [
            find.widgetWithText(TextButton, loc.cancel),
            find.widgetWithText(ElevatedButton, loc.confirm),
          ]) {
            expect(
              find.ancestor(of: button, matching: find.byType(Tooltip)),
              findsNothing,
            );
          }
          final title = find.text(points ? '-23.4 points' : '-23.4 TWD');
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          await mouse.moveTo(tester.getCenter(title));
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          expect(find.text(loc.tapToEditRecordHint), findsOneWidget);
          expect(edits, 0); // Hover never edits or submits.
          await tester.tap(title);
          await tester.pump();
          expect(edits, 1);
          expect(find.byType(AlertDialog), findsOneWidget);
          await mouse.removePointer();
          await tester.tap(find.widgetWithText(TextButton, loc.cancel));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(tester.takeException(), null);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets('touch long-press shows hint without invoking edit', (
    tester,
  ) async {
    var edits = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WidgetsRecordPreviewTile(
            title: const Text('23.4'),
            subtitle: const Text('分類\n日期時間'),
            onTap: () => edits++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('23.4'));
    await tester.pumpAndSettle();
    expect(find.text('點一下可以編輯資料'), findsOneWidget);
    expect(edits, 0);
    await tester.pumpWidget(const SizedBox());
  });
}

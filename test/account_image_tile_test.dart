import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/accounting/widgets_account_image_tile.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

void main() {
  final pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jcWQAAAAASUVORK5CYII=',
  );
  for (final hasThumbnail in [true, false]) {
    testWidgets('card loads image before opening preview ($hasThumbnail)', (
      tester,
    ) async {
      var originals = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AccountImageTile(
              name: 'Wallet',
              loadThumbnail: () async => hasThumbnail ? pixel : null,
              loadImage: () async {
                originals++;
                return pixel;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(originals, hasThumbnail ? 0 : 1);
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(originals, 1);
    });
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/accounting/widgets_account_image_tile.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

void main() {
  Future<Size> imageSize(WidgetTester tester, double width) async {
    const key = ValueKey('account-image');
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(size: Size(width, 800)),
            child: AccountImageTile(
              key: key,
              name: 'Account',
              loadImage: () async => Uint8List(0),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.getSize(find.byKey(key));
  }

  testWidgets('account image grows smoothly across phone widths', (
    tester,
  ) async {
    expect((await imageSize(tester, 360)).width, 92);
    expect((await imageSize(tester, 390)).width, 97.5);
    expect((await imageSize(tester, 480)).width, 120);
  });
}

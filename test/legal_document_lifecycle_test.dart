import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/widgets/dialogs/legal_document_dialog.dart';

class _Bundle extends CachingAssetBundle {
  final data = <String, Future<String>>{};
  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
  @override
  Future<String> loadString(String key, {bool cache = true}) => data[key]!;
}

void main() {
  testWidgets(
    'changing legal document does not inherit old scroll completion',
    (tester) async {
      final bundle = _Bundle();
      final pending = Completer<String>();
      final text = '<p>${List.generate(300, (i) => 'Line $i<br>').join()}</p>';
      bundle.data['privacy'] = Future.value(text);
      bundle.data['terms'] = pending.future;
      var privacy = 0, terms = 0;
      Widget page(String path) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LegalDocumentDialog(
            key: const ValueKey('legal'),
            bundle: bundle,
            assetPath: path,
            onReadComplete: () => path == 'privacy' ? privacy++ : terms++,
          ),
        ),
      );
      await tester.pumpWidget(page('privacy'));
      await tester.pumpAndSettle();
      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      scroll.controller!.jumpTo(scroll.controller!.position.maxScrollExtent);
      await tester.pump();
      expect(privacy, 1);
      await tester.pumpWidget(page('terms'));
      await tester.pump();
      expect(terms, 0);
      pending.complete(text);
      await tester.pumpAndSettle();
      expect(terms, 0);
      final next = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(next.controller!.offset, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

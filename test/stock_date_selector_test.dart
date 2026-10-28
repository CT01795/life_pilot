import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/stock/widgets_stock_date_selector.dart';

final _day = DateTime(2026, 10, 28);
Widget _app({
  String locale = 'en',
  bool enabled = true,
  bool loading = false,
  Future<void> Function(DateTime)? onSelected,
}) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(8),
      child: WidgetsStockDateSelector(
        selectedDate: _day,
        latestAvailableDate: _day,
        enabled: enabled,
        loading: loading,
        onSelected: onSelected ?? (_) async {},
      ),
    ),
  ),
);

void main() {
  for (final locale in ['zh', 'en', 'ja', 'ko']) {
    testWidgets(
      '$locale date label fits narrow screen and retains full tooltip',
      (tester) async {
        tester.view.physicalSize = const Size(240, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_app(locale: locale));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Tooltip>(find.byType(Tooltip)).message,
          contains('2026/10/28'),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'disabled date selector has no action; enabled picker limits date and reports selection',
    (tester) async {
      DateTime? selected;
      await tester.pumpWidget(_app(enabled: false, loading: true));
      await tester.pump();
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(
        _app(
          onSelected: (value) async {
            selected = value;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.lastDate, _day);
      await tester.tap(find.text('27'));
      final context = tester.element(find.byType(DatePickerDialog));
      await tester.tap(
        find.text(MaterialLocalizations.of(context).okButtonLabel),
      );
      await tester.pumpAndSettle();
      expect(selected, DateTime(2026, 10, 27));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelling date selection does not request data', (
    tester,
  ) async {
    var selections = 0;
    await tester.pumpWidget(
      _app(
        onSelected: (_) async {
          selections++;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(DatePickerDialog));
    await tester.tap(
      find.text(MaterialLocalizations.of(context).cancelButtonLabel),
    );
    await tester.pumpAndSettle();
    expect(selections, 0);
    expect(tester.takeException(), isNull);
  });
}

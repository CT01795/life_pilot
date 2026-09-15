import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_card_header.dart';

void main() {
  const trailingKey = Key('header-trailing');

  Future<void> pumpHeader(WidgetTester tester, double width) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: const DashboardCardHeader(
                icon: Icons.local_activity,
                title: 'Recommended activities',
                trailingWidth: 180,
                trailing: SizedBox(key: trailingKey, height: 40),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('keeps title and trailing control on one row when they fit', (
    tester,
  ) async {
    await pumpHeader(tester, 800);

    final titleCenter = tester
        .getCenter(find.text('Recommended activities'))
        .dy;
    final trailingCenter = tester.getCenter(find.byKey(trailingKey)).dy;

    expect((titleCenter - trailingCenter).abs(), lessThan(1));
  });

  testWidgets('moves trailing control below title only when width is short', (
    tester,
  ) async {
    await pumpHeader(tester, 300);

    final titleBottom = tester
        .getBottomLeft(find.text('Recommended activities'))
        .dy;
    final trailingTop = tester.getTopLeft(find.byKey(trailingKey)).dy;

    expect(trailingTop, greaterThan(titleBottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow on a narrow screen with enlarged text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const Scaffold(
            body: SizedBox(
              width: 220,
              child: DashboardCardHeader(
                icon: Icons.account_balance_wallet,
                title: 'Income and expense records',
                trailingWidth: 40,
                trailing: SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

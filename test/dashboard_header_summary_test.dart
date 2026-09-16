import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_header_summary.dart';

void main() {
  testWidgets('summary scales down without overflowing on a phone header', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 112,
            child: DashboardHeaderSummary(
              value: '1,234,567.8901 TWD',
              tooltip: 'Today total',
            ),
          ),
        ),
      ),
    );

    expect(find.text('1,234,567.8901 TWD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('summary displays a compact loading indicator', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DashboardHeaderSummary(
            value: '0',
            tooltip: 'Loading',
            isLoading: true,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}

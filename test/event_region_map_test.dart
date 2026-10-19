import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/model_event_regions.dart';
import 'package:life_pilot/event/widgets_event_map.dart' show WidgetsEventMap;

void main() {
  testWidgets('map counts still select the normalized city', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WidgetsEventMap(
            regionData: EventRegionData.fromEvents([
              EventItem(id: 'a', name: '', city: '臺北市'),
            ]),
            onCitySelected: (city) => selected = city,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('台北 1'));
    expect(selected, '台北');
    expect(tester.takeException(), isNull);
  });

  testWidgets('international and island chips retain full city selection', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WidgetsEventMap(
            regionData: EventRegionData.fromEvents([
              EventItem(id: 'a', name: '', city: 'Singapore'),
              EventItem(id: 'b', name: '', city: '澎湖縣'),
            ]),
            onCitySelected: (city) => selected = city,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Singapore  1'));
    expect(selected, 'Singapore');
    await tester.tap(find.text('澎湖  1'));
    expect(selected, '澎湖');
    expect(tester.takeException(), isNull);
  });
}

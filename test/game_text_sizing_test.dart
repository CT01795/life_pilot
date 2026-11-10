import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/game_text_sizing.dart';

void main() {
  Future<(double, double)> sizes(WidgetTester tester, double width) async {
    late double question;
    late double answer;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: Builder(
          builder: (context) {
            question = GameTextSizing.question(context, 'Translate this');
            answer = GameTextSizing.answer(context, 'An answer');
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return (question, answer);
  }

  testWidgets('phone game questions remain larger than ordinary body text', (
    tester,
  ) async {
    final (question, answer) = await sizes(tester, 360);
    expect(question, greaterThanOrEqualTo(30));
    expect(answer, greaterThanOrEqualTo(26));
  });

  testWidgets('game text grows on wider screens', (tester) async {
    final phone = await sizes(tester, 360);
    final tablet = await sizes(tester, 900);
    expect(tablet.$1, greaterThan(phone.$1));
    expect(tablet.$2, greaterThan(phone.$2));
  });

  testWidgets('long questions shrink but keep an accessible minimum', (
    tester,
  ) async {
    late double size;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(320, 700)),
        child: Builder(
          builder: (context) {
            size = GameTextSizing.question(
              context,
              List.filled(40, 'word').join(' '),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(size, greaterThanOrEqualTo(26));
  });
}

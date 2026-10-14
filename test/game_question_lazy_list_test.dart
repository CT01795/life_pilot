import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/game/page_game_my_questions.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('long question lists build offscreen cards only when scrolled', (
    tester,
  ) async {
    final service = _PagedQuestions();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    expect(find.text('Question19'), findsNothing);
    expect(service.offsets, [0]);
    await tester.scrollUntilVisible(
      find.text('Question19'),
      350,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 30,
    );
    await tester.pumpAndSettle();
    expect(find.text('Question19'), findsOneWidget);
    expect(find.text('Question0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'phone list supports loading more and retains one scroll surface',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _PagedQuestions();
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('See more...'),
        350,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 30,
      );
      await tester.tap(find.text('See more...'));
      await tester.pumpAndSettle();
      expect(service.offsets, [0, 20]);
      expect(service.groupCalls, 1);
      await tester.scrollUntilVisible(
        find.text('Question39'),
        350,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 30,
      );
      await tester.pumpAndSettle();
      expect(find.text('Question39'), findsOneWidget);
      expect(find.text('See more...'), findsNothing);
      expect(find.byType(Scrollable), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app(ServiceGame service) => ChangeNotifierProvider<ControllerAuth>(
  create: (_) => _TestAuth(),
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PageGameMyQuestions(
      gameName: 'Speaking',
      initialLevel: 1,
      service: service,
    ),
  ),
);

class _TestAuth extends ControllerAuth {
  @override
  bool get isSysAdmin => false;
}

class _PagedQuestions extends ServiceGame {
  final offsets = <int>[];
  int groupCalls = 0;

  @override
  Future<MyGameQuestionPage> fetchMyQuestions({
    required String gameName,
    String keyword = '',
    String? group,
    String status = 'all',
    int offset = 0,
    int limit = 20,
  }) async {
    offsets.add(offset);
    return MyGameQuestionPage(
      questions: List.generate(
        limit,
        (index) => MyGameQuestion(
          id: '${offset + index}',
          question: 'Question${offset + index}',
          answer: 'Answer',
          group: 'grammar',
          level: 1,
          isActive: true,
        ),
      ),
      totalCount: 40,
    );
  }

  @override
  Future<List<String>> fetchMyQuestionGroupsForManagement({
    required String gameName,
  }) async {
    groupCalls++;
    return ['grammar'];
  }
}

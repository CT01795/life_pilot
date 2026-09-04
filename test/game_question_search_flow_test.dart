import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/page_game_my_questions.dart';
import 'package:life_pilot/game/page_game_question_create.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/social/page_game_social_question_create.dart';
import 'package:life_pilot/game/social/page_game_social_questions.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('question search applies only after submit and combines category',
      (tester) async {
    final service = _FakeGameService(groups: const ['grammar']);
    await tester.pumpWidget(_app(
      PageGameMyQuestions(
        gameName: 'English RPG Adventure',
        initialLevel: 4,
        service: service,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'We are young');
    await tester.pump();
    expect(service.lastKeyword, '');

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(service.lastKeyword, 'We are young');

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('grammar').last);
    await tester.pumpAndSettle();

    expect(service.lastKeyword, 'We are young');
    expect(service.lastGroup, 'grammar');
    expect(find.text('新增題目'), findsOneWidget);
  });

  testWidgets('successful question creation reloads with carried filters',
      (tester) async {
    final service = _FakeGameService(groups: const ['grammar']);
    String? carriedQuestion;
    String? carriedGroup;
    int? carriedLevel;
    await tester.pumpWidget(_app(
      PageGameMyQuestions(
        gameName: 'English RPG Adventure',
        initialLevel: 4,
        service: service,
        createPageBuilder: (question, group, level) {
          carriedQuestion = question;
          carriedGroup = group;
          carriedLevel = level;
          return const _SuccessfulCreatePage();
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'We are young');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('grammar').last);
    await tester.pumpAndSettle();
    final callsBeforeAdd = service.questionPageCalls;

    await tester.tap(find.text('新增題目'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成新增'));
    await tester.pumpAndSettle();

    expect(carriedQuestion, 'We are young');
    expect(carriedGroup, 'grammar');
    expect(carriedLevel, 4);
    expect(service.questionPageCalls, greaterThan(callsBeforeAdd));
  });

  testWidgets('Social search applies only after submit and combines category',
      (tester) async {
    final service = _FakeGameService(categories: const ['friendship']);
    await tester.pumpWidget(
      _app(PageGameSocialQuestions(service: service)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '朋友吵架');
    await tester.pump();
    expect(service.lastSocialKeyword, '');

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('friendship').last);
    await tester.pumpAndSettle();

    expect(service.lastSocialKeyword, '朋友吵架');
    expect(service.lastCategory, 'friendship');
    expect(find.text('新增題目'), findsOneWidget);
  });

  testWidgets('successful Social creation reloads with carried filters',
      (tester) async {
    final service = _FakeGameService(categories: const ['friendship']);
    String? carriedTitle;
    String? carriedCategory;
    await tester.pumpWidget(_app(PageGameSocialQuestions(
      service: service,
      createPageBuilder: (title, category) {
        carriedTitle = title;
        carriedCategory = category;
        return const _SuccessfulCreatePage();
      },
    )));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '朋友吵架');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('friendship').last);
    await tester.pumpAndSettle();
    final callsBeforeAdd = service.socialPageCalls;

    await tester.tap(find.text('新增題目'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成新增'));
    await tester.pumpAndSettle();

    expect(carriedTitle, '朋友吵架');
    expect(carriedCategory, 'friendship');
    expect(service.socialPageCalls, greaterThan(callsBeforeAdd));
  });

  test('create pages retain initial search values', () {
    const regular = PageGameQuestionCreate(
      gameName: 'English RPG Adventure',
      initialLevel: 4,
      initialQuestion: 'We are young',
      initialGroup: 'grammar',
    );
    const social = PageGameSocialQuestionCreate(
      initialTitle: '朋友吵架',
      initialCategory: 'friendship',
    );

    expect(regular.initialQuestion, 'We are young');
    expect(regular.initialGroup, 'grammar');
    expect(social.initialTitle, '朋友吵架');
    expect(social.initialCategory, 'friendship');
  });
}

Widget _app(Widget home) => ChangeNotifierProvider<ControllerAuth>(
      create: (_) => _FakeControllerAuth(),
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

class _FakeGameService extends ServiceGame {
  _FakeGameService({this.groups = const [], this.categories = const []});

  final List<String> groups;
  final List<String> categories;
  String? lastKeyword;
  String? lastGroup;
  String? lastSocialKeyword;
  String? lastCategory;
  int questionPageCalls = 0;
  int socialPageCalls = 0;

  @override
  Future<MyGameQuestionPage> fetchMyQuestions({
    required String gameName,
    String keyword = '',
    String? group,
    String status = 'all',
    int offset = 0,
    int limit = 20,
  }) async {
    questionPageCalls++;
    lastKeyword = keyword;
    lastGroup = group;
    return const MyGameQuestionPage(questions: [], totalCount: 0);
  }

  @override
  Future<List<String>> fetchMyQuestionGroupsForManagement({
    required String gameName,
  }) async =>
      groups;

  @override
  Future<MySocialQuestionPage> fetchMySocialQuestions({
    String keyword = '',
    String? category,
    String status = 'all',
    int offset = 0,
    int limit = 20,
  }) async {
    socialPageCalls++;
    lastSocialKeyword = keyword;
    lastCategory = category;
    return const MySocialQuestionPage(questions: [], totalCount: 0);
  }

  @override
  Future<List<String>> fetchMySocialQuestionCategories() async => categories;
}

class _SuccessfulCreatePage extends StatelessWidget {
  const _SuccessfulCreatePage();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('完成新增'),
          ),
        ),
      );
}

class _FakeControllerAuth extends ControllerAuth {
  @override
  bool get isSysAdmin => false;
}

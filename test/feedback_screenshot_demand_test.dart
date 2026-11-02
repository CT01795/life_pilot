import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/feedback/controller_feedback_admin.dart';
import 'package:life_pilot/feedback/model_feedback.dart';
import 'package:life_pilot/feedback/service_feedback.dart';
import 'package:life_pilot/feedback/page_feedback_admin.dart';
import 'package:life_pilot/feedback/widgets_feedback_image_loader.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class _Auth extends ControllerAuth {
  String account = 'admin@example.com';
  @override
  String get currentAccount => account;
  @override
  bool get isSysAdmin => true;
  void change() {
    account = 'other@example.com';
    notifyListeners();
  }
}

class _Service extends ServiceFeedback {
  int images = 0, metadata = 0, id = 1;
  bool fail = false;
  Completer<List<String>>? gate;
  @override
  Future<List<dynamic>> loadFeedback({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    metadata++;
    return [
      {
        'id': id,
        'subject': 'Feedback $id',
        'content': 'Full feedback text',
        'created_at': '2026-11-01T00:00:00Z',
        'status': 'pending',
      },
    ];
  }

  @override
  Future<bool> hasFeedbackBefore(DateTime before) async => false;
  @override
  Future<List<String>> loadScreenshots(int id) async {
    images++;
    if (fail) throw StateError('offline');
    return gate?.future ?? [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Service service;
  late ControllerFeedbackAdmin controller;
  setUp(() async {
    auth = _Auth();
    service = _Service();
    controller = ControllerFeedbackAdmin(service, auth);
    await controller.loadFeedback();
  });
  tearDown(() {
    controller.dispose();
    auth.dispose();
  });
  Future<AppLocalizations> mount(
    WidgetTester tester, {
    String language = 'en',
    ModelFeedback? feedback,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: WidgetsFeedbackImageLoader(
              controller: controller,
              feedback: feedback ?? controller.feedbackList.single,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(WidgetsFeedbackImageLoader)),
    )!;
  }

  testWidgets(
    'opening actual text details does not fetch images; explicit action and reopen reuse results',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<ControllerAuth>.value(
          value: auth,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PageFeedbackAdmin(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.images, 0);
      final reads = service.metadata;
      await tester.tap(find.text('Feedback 1'));
      await tester.pumpAndSettle();
      expect(service.images, 0);
      expect(find.text('Full feedback text'), findsWidgets);
      final loc = AppLocalizations.of(
        tester.element(find.byType(AlertDialog)),
      )!;
      await tester.tap(find.text(loc.viewFeedbackScreenshots));
      await tester.pumpAndSettle();
      expect(service.images, 1);
      expect(find.text(loc.noFeedbackScreenshots), findsOneWidget);
      await tester.tap(find.text(loc.close));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Feedback 1'));
      await tester.pumpAndSettle();
      expect(service.images, 1);
      expect(service.metadata, reads);
      expect(find.text(loc.noFeedbackScreenshots), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('immediate failure provides retry without an unhandled future', (
    tester,
  ) async {
    final loc = await mount(tester);
    service.fail = true;
    await tester.tap(find.text(loc.viewFeedbackScreenshots));
    await tester.pumpAndSettle();
    expect(service.images, 1);
    expect(find.text(loc.retry), findsOneWidget);
    expect(controller.feedbackList.single.screenshotsLoaded, isFalse);
    service.fail = false;
    await tester.tap(find.text(loc.retry));
    await tester.pumpAndSettle();
    expect(service.images, 2);
    expect(find.text(loc.noFeedbackScreenshots), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'pending image request hides its trigger and cannot send duplicates',
    (tester) async {
      final loc = await mount(tester);
      service.gate = Completer<List<String>>();
      await tester.tap(find.text(loc.viewFeedbackScreenshots));
      await tester.pump();
      expect(service.images, 1);
      expect(find.text(loc.viewFeedbackScreenshots), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      service.gate!.complete([]);
      await tester.pumpAndSettle();
      expect(service.images, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'account switch hides old dialog content and rejects late private images',
    (tester) async {
      final row = controller.feedbackList.single;
      final loc = await mount(tester);
      service.gate = Completer<List<String>>();
      await tester.tap(find.text(loc.viewFeedbackScreenshots));
      await tester.pump();
      auth.change();
      await tester.pump();
      service.gate!.complete(['old-private-image']);
      await tester.pumpAndSettle();
      expect(row.screenshotsLoaded, isFalse);
      expect(row.screenshot, isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(loc.viewFeedbackScreenshots), findsNothing);
      expect(service.images, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'closing during download handles later failure without view errors',
    (tester) async {
      final loc = await mount(tester);
      service.gate = Completer<List<String>>();
      await tester.tap(find.text(loc.viewFeedbackScreenshots));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      service.gate!.completeError(StateError('late'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'replacing the feedback resets the old image state without an eager request',
    (tester) async {
      final loc = await mount(tester);
      await tester.tap(find.text(loc.viewFeedbackScreenshots));
      await tester.pumpAndSettle();
      expect(service.images, 1);
      service.id = 2;
      await controller.loadFeedback();
      await mount(tester);
      expect(find.text(loc.viewFeedbackScreenshots), findsOneWidget);
      expect(service.images, 1);
      await tester.tap(find.text(loc.viewFeedbackScreenshots));
      await tester.pumpAndSettle();
      expect(service.images, 2);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'unloaded and stale rows cannot trigger queries even if marked cached',
    () async {
      final stale = controller.feedbackList.single;
      await controller.loadFeedback();
      await expectLater(controller.loadScreenshots(stale), throwsStateError);
      final unknown = ModelFeedback(
        id: 999,
        subject: 'unknown',
        content: 'x',
        createdAt: DateTime(2026),
      );
      await expectLater(controller.loadScreenshots(unknown), throwsStateError);
      expect(service.images, 0);
    },
  );
  for (final language in ['zh', 'en', 'ja', 'ko']) {
    testWidgets(
      '$language: demand button and empty message fit narrow screens',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final loc = await mount(tester, language: language);
        expect(service.images, 0);
        await tester.tap(find.text(loc.viewFeedbackScreenshots));
        await tester.pumpAndSettle();
        expect(find.text(loc.noFeedbackScreenshots), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

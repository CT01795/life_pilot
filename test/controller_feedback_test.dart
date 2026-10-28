import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/feedback/controller_feedback.dart';
import 'package:life_pilot/feedback/model_feedback_submission.dart';
import 'package:life_pilot/feedback/page_feedback.dart';
import 'package:life_pilot/feedback/service_feedback.dart';
import 'package:life_pilot/feedback/service_feedback_screenshot.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _Auth extends ControllerAuth {
  String account = 'a@example.com';
  @override
  String get currentAccount => account;
  void switchTo(String next) {
    account = next;
    notifyListeners();
  }
}

class _Service extends ServiceFeedback {
  final calls = <Map<String, Object?>>[];
  Completer<void>? pending;
  bool fail = false;
  @override
  Future<void> sendFeedback({
    required String account,
    required String subject,
    required String content,
    List<String>? cc,
    List<Uint8List>? screenshots,
  }) async {
    calls.add({
      'account': account,
      'subject': subject,
      'content': content,
      'cc': cc,
      'screenshots': screenshots,
    });
    if (pending != null) await pending!.future;
    if (fail) throw StateError('offline');
  }
}

class _Screenshot extends ServiceFeedbackScreenshot {
  int calls = 0;
  bool fail = false;
  Completer<Uint8List?>? pending;
  @override
  Future<Uint8List?> capture() async {
    calls++;
    if (fail) throw StateError('capture failed');
    return pending?.future ?? Future.value(Uint8List.fromList([1, 2, 3]));
  }
}

ControllerFeedback _controller(
  _Service service, {
  _Auth? auth,
  _Screenshot? screenshot,
}) =>
    ControllerFeedback(
        service,
        auth ?? _Auth(),
        screenshotService: screenshot ?? _Screenshot(),
      )
      ..subject = 'Subject'
      ..content = 'Content';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'account change clears draft and screenshots, same-account notifications do not',
    () async {
      final auth = _Auth();
      final c = _controller(_Service(), auth: auth)..ccRaw = 'cc@example.com';
      addTearDown(c.dispose);
      await c.captureScreenshot();
      final images = c.screenshot;
      expect(c.screenshot, same(images));
      auth.switchTo(auth.account);
      expect(c.subject, 'Subject');
      expect(c.screenshot, hasLength(1));
      auth.switchTo('b@example.com');
      expect(c.subject, '');
      expect(c.content, '');
      expect(c.ccRaw, isNull);
      expect(c.screenshot, isEmpty);
      expect(c.draftRevision, 1);
    },
  );

  test(
    'old submit completion cannot release the new account busy state',
    () async {
      final auth = _Auth();
      final old = Completer<void>(), fresh = Completer<void>();
      final service = _Service()..pending = old;
      final c = _controller(service, auth: auth);
      addTearDown(c.dispose);
      final first = c.submit();
      auth.switchTo('b@example.com');
      c.subject = 'New subject';
      c.content = 'New content';
      service.pending = fresh;
      final second = c.submit();
      old.complete();
      expect(await first, isNull);
      expect(c.isSending, isTrue);
      expect(c.content, 'New content');
      fresh.complete();
      expect((await second)!.status, FeedbackSubmissionStatus.sent);
      expect(c.isSending, isFalse);
      expect(service.calls.map((call) => call['account']), [
        'a@example.com',
        'b@example.com',
      ]);
    },
  );

  test(
    'old screenshot cannot append images or release a new capture',
    () async {
      final auth = _Auth();
      final old = Completer<Uint8List?>(), fresh = Completer<Uint8List?>();
      final screenshot = _Screenshot()..pending = old;
      final c = _controller(_Service(), auth: auth, screenshot: screenshot);
      addTearDown(c.dispose);
      final first = c.captureScreenshot();
      auth.switchTo('b@example.com');
      screenshot.pending = fresh;
      final second = c.captureScreenshot();
      old.complete(Uint8List.fromList([1]));
      expect(await first, isNull);
      expect(c.isCapturing, isTrue);
      expect(c.screenshot, isEmpty);
      fresh.complete(Uint8List.fromList([2]));
      expect(await second, isTrue);
      expect(c.screenshot.single, [2]);
      expect(c.isCapturing, isFalse);
    },
  );

  test(
    'returning to the original account cannot revive its previous submission',
    () async {
      final auth = _Auth();
      final service = _Service()..pending = Completer<void>();
      final c = _controller(service, auth: auth);
      addTearDown(c.dispose);
      final first = c.submit();
      auth.switchTo('b@example.com');
      auth.switchTo('a@example.com');
      service.pending!.complete();
      expect(await first, isNull);
      expect(c.subject, '');
      expect(c.draftRevision, 2);
    },
  );

  test(
    'account change during start notification prevents an obsolete send',
    () async {
      final auth = _Auth(), service = _Service();
      final c = _controller(service, auth: auth);
      addTearDown(c.dispose);
      var switched = false;
      c.addListener(() {
        if (switched || !c.isSending) return;
        switched = true;
        auth.switchTo('b@example.com');
      });
      expect(await c.submit(), isNull);
      expect(service.calls, isEmpty);
    },
  );

  testWidgets('switching account resets the visible feedback input fields', (
    tester,
  ) async {
    final auth = _Auth();
    final c = _controller(_Service(), auth: auth);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PageFeedbackBody(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), 'Old subject');
    await tester.enterText(find.byType(TextField).at(1), 'Old content');
    auth.switchTo('b@example.com');
    await tester.pumpAndSettle();
    for (final editable in tester.widgetList<EditableText>(
      find.byType(EditableText),
    )) {
      expect(editable.controller.text, '');
    }
    expect(c.subject, '');
    expect(c.content, '');
    expect(tester.takeException(), isNull);
  });

  test('blank input returns validation result without sending', () async {
    final service = _Service();
    final c = _controller(service)..subject = '   ';
    addTearDown(c.dispose);
    expect((await c.submit())!.status, FeedbackSubmissionStatus.requiredFields);
    expect(service.calls, isEmpty);
    expect(c.isSending, false);
  });
  test(
    'submission captures account, fields, CC and screenshot snapshot',
    () async {
      final service = _Service();
      final c = _controller(service)
        ..ccRaw = ' first@example.com, , second@example.com ';
      addTearDown(c.dispose);
      await c.captureScreenshot();
      expect((await c.submit())!.status, FeedbackSubmissionStatus.sent);
      expect(service.calls.single['account'], 'a@example.com');
      expect(service.calls.single['subject'], 'Subject');
      expect(service.calls.single['cc'], [
        'first@example.com',
        'second@example.com',
      ]);
      expect(service.calls.single['screenshots'] as List, hasLength(1));
      expect(() => c.screenshot.clear(), throwsUnsupportedError);
    },
  );
  test('sending blocks duplicate submission and screenshot capture', () async {
    final service = _Service()..pending = Completer<void>();
    final c = _controller(service);
    addTearDown(c.dispose);
    final request = c.submit();
    c.subject = 'Changed';
    expect(await c.submit(), isNull);
    expect(await c.captureScreenshot(), isNull);
    service.pending!.complete();
    expect((await request)!.status, FeedbackSubmissionStatus.sent);
    expect(service.calls, hasLength(1));
    expect(service.calls.single['subject'], 'Subject');
  });
  test(
    'send failure returns error, preserves draft and permits retry',
    () async {
      final service = _Service()..fail = true;
      final c = _controller(service);
      addTearDown(c.dispose);
      final result = (await c.submit())!;
      expect(result.status, FeedbackSubmissionStatus.failed);
      expect(result.error, isStateError);
      expect(c.content, 'Content');
      expect(c.isSending, false);
      service.fail = false;
      expect((await c.submit())!.status, FeedbackSubmissionStatus.sent);
    },
  );
  test(
    'capture blocks duplicate capture and submission until finished',
    () async {
      final screenshot = _Screenshot()..pending = Completer<Uint8List?>();
      final c = _controller(_Service(), screenshot: screenshot);
      addTearDown(c.dispose);
      final request = c.captureScreenshot();
      expect(c.isCapturing, true);
      expect(await c.captureScreenshot(), isNull);
      expect(await c.submit(), isNull);
      screenshot.pending!.complete(Uint8List(3));
      expect(await request, true);
      expect(screenshot.calls, 1);
      expect(c.isCapturing, false);
    },
  );
  test('capture failure is recoverable', () async {
    final screenshot = _Screenshot()..fail = true;
    final c = _controller(_Service(), screenshot: screenshot);
    addTearDown(c.dispose);
    expect(await c.captureScreenshot(), false);
    expect(c.screenshot, isEmpty);
    expect(c.isCapturing, false);
    screenshot.fail = false;
    expect(await c.captureScreenshot(), true);
  });
  test('late screenshot after disposal is not stored or notified', () async {
    final screenshot = _Screenshot()..pending = Completer<Uint8List?>();
    final c = _controller(_Service(), screenshot: screenshot);
    var notifications = 0;
    c.addListener(() => notifications++);
    final request = c.captureScreenshot();
    final before = notifications;
    c.dispose();
    screenshot.pending!.complete(Uint8List(3));
    expect(await request, isNull);
    expect(c.screenshot, isEmpty);
    expect(notifications, before);
  });
  test('late submission after disposal does not notify View', () async {
    final service = _Service()..pending = Completer<void>();
    final c = _controller(service);
    var notifications = 0;
    c.addListener(() => notifications++);
    final request = c.submit();
    final before = notifications;
    c.dispose();
    service.pending!.complete();
    expect(await request, isNull);
    expect(notifications, before);
  });
  test(
    'old-account completion does not show success for the new account',
    () async {
      final auth = _Auth();
      final service = _Service()..pending = Completer<void>();
      final c = _controller(service, auth: auth);
      addTearDown(c.dispose);
      final request = c.submit();
      auth.account = 'b@example.com';
      service.pending!.complete();
      expect(await request, isNull);
      expect(service.calls.single['account'], 'a@example.com');
    },
  );
  test(
    'screenshot service safely handles a missing capture boundary',
    () async {
      expect(await ServiceFeedbackScreenshot().capture(), isNull);
    },
  );
  testWidgets(
    'View closes the feedback route only after a successful submission',
    (tester) async {
      final service = _Service();
      final c = _controller(service);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: c,
                      child: const PageFeedbackBody(),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'UI subject');
      await tester.enterText(find.byType(TextField).at(1), 'UI content');
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();
      expect(service.calls, hasLength(1));
      expect(service.calls.single['subject'], 'UI subject');
      expect(service.calls.single['content'], 'UI content');
      expect(find.byType(PageFeedbackBody), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/feedback/model_feedback.dart';
import 'package:life_pilot/feedback/widgets_feedback_screenshots.dart';

class _Feedback extends ModelFeedback {
  _Feedback(int count)
    : super(
        id: 1,
        subject: 'Subject',
        content: 'Content',
        createdAt: DateTime(2026),
        screenshot: List.filled(count, 'unused'),
      );
  final reads = <int>[];
  final pending = <int, Completer<Uint8List?>>{};
  final futures = <int, Future<Uint8List?>>{};
  bool delay = false;
  @override
  Future<Uint8List?> decodeScreenshotAsync(int index) =>
      futures.putIfAbsent(index, () {
        reads.add(index);
        return delay
            ? (pending[index] = Completer<Uint8List?>()).future
            : Future.value(null);
      });
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('empty gallery does not create a viewport or decode images', (
    tester,
  ) async {
    final feedback = _Feedback(0);
    await tester.pumpWidget(
      _app(WidgetsFeedbackScreenshots(feedback: feedback)),
    );
    expect(feedback.reads, isEmpty);
    expect(find.byType(ListView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'large gallery decodes only visible thumbnails and builds more on scroll',
    (tester) async {
      final feedback = _Feedback(100);
      await tester.pumpWidget(
        _app(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 280,
              child: WidgetsFeedbackScreenshots(feedback: feedback),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initial = List.of(feedback.reads);
      expect(initial, isNotEmpty);
      expect(initial.length, lessThan(10));
      await tester.drag(find.byType(ListView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(feedback.reads.any((i) => i > initial.last), isTrue);
      expect(feedback.reads.length, lessThan(100));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending and failed decoding have stable thumbnail dimensions', (
    tester,
  ) async {
    final feedback = _Feedback(1)..delay = true;
    await tester.pumpWidget(
      _app(WidgetsFeedbackScreenshots(feedback: feedback)),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    feedback.pending[0]!.complete(null);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.getSize(find.byIcon(Icons.broken_image_outlined)).height,
      120,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery fits feedback dialog in a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final feedback = _Feedback(20);
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Content'),
                      WidgetsFeedbackScreenshots(feedback: feedback),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test(
    'model shares a per-image decode future and its completed result',
    () async {
      final feedback = ModelFeedback(
        id: 1,
        subject: '',
        content: '',
        createdAt: DateTime(2026),
        screenshot: ['AQID'],
      );
      final first = feedback.decodeScreenshotAsync(0);
      expect(feedback.decodeScreenshotAsync(0), same(first));
      expect(await first, [1, 2, 3]);
      expect(feedback.decodeScreenshotAsync(0), same(first));
      expect(await feedback.decodeScreenshotAsync(-1), isNull);
    },
  );

  test(
    'malformed base64 returns a missing image rather than an uncaught error',
    () async {
      final feedback = ModelFeedback(
        id: 1,
        subject: '',
        content: '',
        createdAt: DateTime(2026),
        screenshot: ['%%%'],
      );
      expect(await feedback.decodeScreenshotAsync(0), isNull);
    },
  );
}

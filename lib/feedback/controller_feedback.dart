import 'dart:collection';
import 'dart:typed_data';

import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/feedback/model_feedback_submission.dart';
import 'package:life_pilot/feedback/service_feedback.dart';
import 'package:life_pilot/feedback/service_feedback_screenshot.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

class ControllerFeedback extends SafeChangeNotifier {
  ControllerFeedback(
    ServiceFeedback service,
    this.auth, {
    ServiceFeedbackScreenshot? screenshotService,
  }) : _service = service,
       _screenshotService = screenshotService ?? ServiceFeedbackScreenshot();

  final ServiceFeedback _service;
  final ServiceFeedbackScreenshot _screenshotService;
  final ControllerAuth auth;
  String subject = '';
  String content = '';
  String? ccRaw;
  final List<Uint8List> _screenshots = [];
  List<Uint8List> get screenshot => UnmodifiableListView(_screenshots);
  bool isSending = false;
  bool isCapturing = false;

  String get _account => auth.currentAccount ?? AuthConstants.guest;
  bool _isCurrentOwner(String account) =>
      !notifierDisposed && _account == account;

  Future<bool?> captureScreenshot() async {
    if (notifierDisposed || isCapturing || isSending) return null;
    final account = _account;
    isCapturing = true;
    notifyListeners();
    try {
      final bytes = await _screenshotService.capture();
      if (!_isCurrentOwner(account)) return null;
      if (bytes == null) return false;
      _screenshots.add(bytes);
      return true;
    } catch (error, stackTrace) {
      if (!_isCurrentOwner(account)) return null;
      logger.e(
        'Capture feedback screenshot failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      isCapturing = false;
      notifyListeners();
    }
  }

  /// Null denotes an ignored duplicate, disposal, or account change.
  Future<FeedbackSubmissionResult?> submit() async {
    if (notifierDisposed || isSending || isCapturing) return null;
    final inputSubject = subject;
    final inputContent = content;
    if (inputSubject.trim().isEmpty || inputContent.trim().isEmpty) {
      return const FeedbackSubmissionResult(
        FeedbackSubmissionStatus.requiredFields,
      );
    }
    final account = _account;
    final ccList = ccRaw
        ?.split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final images = List<Uint8List>.unmodifiable(_screenshots);
    isSending = true;
    notifyListeners();
    try {
      await _service.sendFeedback(
        account: account,
        subject: inputSubject,
        content: inputContent,
        cc: ccList,
        screenshots: images,
      );
      if (!_isCurrentOwner(account)) return null;
      return const FeedbackSubmissionResult(FeedbackSubmissionStatus.sent);
    } catch (error) {
      if (!_isCurrentOwner(account)) return null;
      return FeedbackSubmissionResult(
        FeedbackSubmissionStatus.failed,
        error: error,
      );
    } finally {
      isSending = false;
      notifyListeners();
    }
  }
}

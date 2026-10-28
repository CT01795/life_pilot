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
       _screenshotService = screenshotService ?? ServiceFeedbackScreenshot() {
    _owner = _account;
    auth.addListener(_onOwnerChanged);
  }

  final ServiceFeedback _service;
  final ServiceFeedbackScreenshot _screenshotService;
  final ControllerAuth auth;
  String subject = '';
  String content = '';
  String? ccRaw;
  final List<Uint8List> _screenshots = [];
  late final List<Uint8List> _screenshotView = UnmodifiableListView(
    _screenshots,
  );
  List<Uint8List> get screenshot => _screenshotView;
  late String _owner;
  int _ownerRevision = 0;
  int get draftRevision => _ownerRevision;
  bool isSending = false;
  bool isCapturing = false;

  String get _account => auth.currentAccount ?? AuthConstants.guest;
  bool _isCurrentOwner(String account, int revision) =>
      !notifierDisposed &&
      _account == account &&
      _owner == account &&
      revision == _ownerRevision;

  void _onOwnerChanged() {
    if (notifierDisposed || _owner == _account) return;
    _owner = _account;
    _ownerRevision++;
    subject = '';
    content = '';
    ccRaw = null;
    _screenshots.clear();
    isSending = false;
    isCapturing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    auth.removeListener(_onOwnerChanged);
    super.dispose();
  }

  Future<bool?> captureScreenshot() async {
    if (notifierDisposed) return null;
    _onOwnerChanged();
    if (isCapturing || isSending) return null;
    final account = _account;
    final revision = _ownerRevision;
    isCapturing = true;
    notifyListeners();
    try {
      if (!_isCurrentOwner(account, revision)) return null;
      final bytes = await _screenshotService.capture();
      if (!_isCurrentOwner(account, revision)) return null;
      if (bytes == null) return false;
      _screenshots.add(bytes);
      return true;
    } catch (error, stackTrace) {
      if (!_isCurrentOwner(account, revision)) return null;
      logger.e(
        'Capture feedback screenshot failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      if (_isCurrentOwner(account, revision)) {
        isCapturing = false;
        notifyListeners();
      }
    }
  }

  /// Null denotes an ignored duplicate, disposal, or account change.
  Future<FeedbackSubmissionResult?> submit() async {
    if (notifierDisposed) return null;
    _onOwnerChanged();
    if (isSending || isCapturing) return null;
    final inputSubject = subject;
    final inputContent = content;
    if (inputSubject.trim().isEmpty || inputContent.trim().isEmpty) {
      return const FeedbackSubmissionResult(
        FeedbackSubmissionStatus.requiredFields,
      );
    }
    final account = _account;
    final revision = _ownerRevision;
    final ccList = ccRaw
        ?.split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final images = List<Uint8List>.unmodifiable(_screenshots);
    isSending = true;
    notifyListeners();
    try {
      if (!_isCurrentOwner(account, revision)) return null;
      await _service.sendFeedback(
        account: account,
        subject: inputSubject,
        content: inputContent,
        cc: ccList,
        screenshots: images,
      );
      if (!_isCurrentOwner(account, revision)) return null;
      return const FeedbackSubmissionResult(FeedbackSubmissionStatus.sent);
    } catch (error) {
      if (!_isCurrentOwner(account, revision)) return null;
      return FeedbackSubmissionResult(
        FeedbackSubmissionStatus.failed,
        error: error,
      );
    } finally {
      if (_isCurrentOwner(account, revision)) {
        isSending = false;
        notifyListeners();
      }
    }
  }
}

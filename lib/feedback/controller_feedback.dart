import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/feedback/service_feedback.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/app_navigator.dart' as app_navigator;
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

class ControllerFeedback extends SafeChangeNotifier {
  final ServiceFeedback _service;
  final ControllerAuth auth;

  ControllerFeedback(ServiceFeedback service, this.auth) : _service = service;

  String subject = '';
  String content = '';
  String? ccRaw;
  List<Uint8List> screenshot = [];

  bool isSending = false;

  final repaintBoundaryKey = GlobalKey();

  Future<void> captureScreenshot() async {
    final context = app_navigator.rootRepaintBoundaryKey.currentContext;
    if (context == null) return;

    final boundary = context.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    if (byteData != null) {
      screenshot.add(byteData.buffer.asUint8List());
      notifyListeners();
    }
  }

  Future<void> submit(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    if (subject.isEmpty || content.isEmpty) {
      _showSnack(context, loc.feedbackRequired);
      return;
    }

    isSending = true;
    notifyListeners();

    try {
      final ccList = ccRaw
          ?.split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      await _service.sendFeedback(
        account: auth.currentAccount ?? AuthConstants.guest,
        subject: subject,
        content: content,
        cc: ccList,
        screenshots: screenshot,
      );
      _showSnack(context, loc.feedbackSent);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      _showSnack(context, loc.feedbackSendFailed(e.toString()));
    } finally {
      isSending = false;
      notifyListeners();
    }
  }
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

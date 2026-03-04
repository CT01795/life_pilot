import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/utils/app_navigator.dart' as app_navigator;
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/feedback/service_feedback.dart';

class ControllerFeedback extends ChangeNotifier {
  final ServiceFeedback _service;
  final ControllerAuth auth;

  ControllerFeedback(ServiceFeedback service, this.auth): _service = service;

  String subject = '';
  String content = '';
  String? ccRaw;
  List<Uint8List> screenshot = []; // 改成非 nullable list

  bool isSending = false;

  final repaintBoundaryKey = GlobalKey();

  Future<void> captureScreenshot() async {
    final context = app_navigator.rootRepaintBoundaryKey.currentContext;
    if (context == null) return;

    final boundary = context.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData =
        await image.toByteData(format: ImageByteFormat.png);
    if(byteData != null){
      screenshot.add(byteData.buffer.asUint8List());
      notifyListeners();
    }
  }

  Future<void> submit(BuildContext context) async {
    if (subject.isEmpty || content.isEmpty) {
      _showSnack(context, 'Subject and content are required');
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
      _showSnack(context, 'Feedback sent successfully ✅');
      Navigator.pop(context); // 🔙 回上一頁
    } catch (e) {
      _showSnack(context, 'Failed to send feedback ❌: $e');
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
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

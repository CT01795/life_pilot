import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:life_pilot/core/logger.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class AppNavigator {
  AppNavigator._(); // 私有構造，避免實例化
  // ---------------- SnackBar ----------------
  static void showSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
  }) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: duration,
            backgroundColor: backgroundColor,
          ),
        );
    });
  }

  // 顯示錯誤訊息
  static void showErrorBar(String error) => showSnackBar('❌ $error', backgroundColor: Colors.redAccent);

  // ---------------- 錯誤攔截 ----------------
  static void initErrorHandling() {
    FlutterError.onError = (FlutterErrorDetails details) {
      logger.e('❌ Flutter Framework Error: ${details.exceptionAsString()}');
      if (details.exceptionAsString().contains('RenderFlex overflowed')) {
        debugPrint('⚠️ RenderFlex overflow 發生在：${details.library}');
        if (details.stack != null) debugPrintStack(stackTrace: details.stack);
      }

      //showError(error: "FlutterError.onError: ${details.stack.toString()}");
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      logger.e('🚨 Uncaught async error: $error');
      debugPrintStack(stackTrace: stack);
      //showError(error: "PlatformDispatcher.instance.onError: $error");
      return true;
    };
  }
}

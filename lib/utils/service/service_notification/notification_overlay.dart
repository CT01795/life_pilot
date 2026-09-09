import 'package:flutter/material.dart';
import 'package:life_pilot/utils/app_navigator.dart' as app_navigator;
import 'package:life_pilot/utils/const.dart';

OverlayState? get currentOverlay =>
    app_navigator.navigatorKey.currentState?.overlay;
BuildContext? get currentContext => app_navigator.navigatorKey.currentContext;
int _webReminderRevision = 0;
OverlayEntry? _activeWebReminder;

int get webReminderRevision => _webReminderRevision;

void cancelWebReminders() {
  _webReminderRevision++;
  final activeReminder = _activeWebReminder;
  if (activeReminder?.mounted == true) {
    activeReminder!.remove();
  }
  _activeWebReminder = null;
}

void showWebOverlay(
    {required String title, required String body, required String tooltip}) {
  final overlay = currentOverlay;
  if (overlay == null) return;

  final previousReminder = _activeWebReminder;
  if (previousReminder?.mounted == true) {
    previousReminder!.remove();
  }

  late OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => PositionedDirectional(
      end: 20,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: Insets.all12,
          color: Colors.white,
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  Gaps.h4,
                  Text(body),
                ],
              ),
              Positioned(
                child: GestureDetector(
                  onTap: () => overlayEntry.remove(),
                  child: Tooltip(
                    message: tooltip,
                    child: Container(
                      padding: Insets.directionalR3,
                      child: Icon(Icons.info_rounded),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  _activeWebReminder = overlayEntry;
  overlay.insert(overlayEntry);

  Future.delayed(const Duration(seconds: 10), () {
    if (overlayEntry.mounted) {
      overlayEntry.remove();
    }
    if (identical(_activeWebReminder, overlayEntry)) {
      _activeWebReminder = null;
    }
  });
}

import 'package:flutter/material.dart';
import 'package:life_pilot/utils/app_navigator.dart' as app_navigator;

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

void showWebOverlay({
  required String title,
  required String body,
  required String tooltip,
}) {
  final overlay = currentOverlay;
  if (overlay == null) return;

  final previousReminder = _activeWebReminder;
  if (previousReminder?.mounted == true) {
    previousReminder!.remove();
  }

  late OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => PositionedDirectional(
      top: 8,
      start: 12,
      end: 12,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: AlignmentDirectional.topEnd,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: MediaQuery.sizeOf(context).height * 0.45,
            ),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: IconButton(
                            tooltip: tooltip,
                            onPressed: () {
                              if (overlayEntry.mounted) overlayEntry.remove();
                              if (identical(_activeWebReminder, overlayEntry)) {
                                _activeWebReminder = null;
                              }
                            },
                            icon: const Icon(Icons.info_rounded),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(title)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(start: 56),
                          child: Text(body),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

import 'package:flutter/material.dart';
import 'package:life_pilot/my_app.dart';
import 'package:life_pilot/utils/core/utils_const.dart';

// notification_overlay.dart
OverlayState? get currentOverlay => navigatorKey.currentState?.overlay;
BuildContext? get currentContext => navigatorKey.currentContext;

void showWebOverlay(
    {required String title, required String body, required String tooltip}) {
  final overlay = currentOverlay;
  if (overlay == null) return;

  late OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => PositionedDirectional(
      end: 20,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: kGapEI12,
          color: Colors.white,
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  kGapH4(),
                  Text(body),
                ],
              ),
              Positioned(
                child: GestureDetector(
                  onTap: () => overlayEntry.remove(),
                  child: Tooltip(
                    message: tooltip,
                    child: Container(
                      padding: kGapEIR3,
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

  overlay.insert(overlayEntry);

  Future.delayed(const Duration(seconds: 10), () {
    if (overlayEntry.mounted) {
      overlayEntry.remove();
    }
  });
}

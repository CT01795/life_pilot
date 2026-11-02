import 'package:flutter/material.dart';
import 'package:life_pilot/feedback/controller_feedback_admin.dart';
import 'package:life_pilot/feedback/model_feedback.dart';
import 'package:life_pilot/feedback/widgets_feedback_screenshots.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

/// Opening text details does not download images. Fetch only on explicit demand.
class WidgetsFeedbackImageLoader extends StatefulWidget {
  const WidgetsFeedbackImageLoader({
    super.key,
    required this.controller,
    required this.feedback,
  });
  final ControllerFeedbackAdmin controller;
  final ModelFeedback feedback;
  @override
  State<WidgetsFeedbackImageLoader> createState() => _ImageLoaderState();
}

class _ImageLoaderState extends State<WidgetsFeedbackImageLoader> {
  Future<void>? _images;
  @override
  void didUpdateWidget(covariant WidgetsFeedbackImageLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feedback != widget.feedback ||
        oldWidget.controller != widget.controller) {
      _images = null;
    }
  }

  void _load() {
    final request = Future<void>.sync(
      () => widget.controller.loadScreenshots(widget.feedback),
    );
    // A fast failure can precede the next FutureBuilder frame; keep it observed.
    request.ignore();
    setState(() {
      _images = request;
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => _body(context),
  );

  Widget _gallery(BuildContext context) =>
      (widget.feedback.screenshot?.isEmpty ?? true)
      ? Text(AppLocalizations.of(context)!.noFeedbackScreenshots)
      : WidgetsFeedbackScreenshots(feedback: widget.feedback);

  Widget _body(BuildContext context) {
    if (!widget.controller.canReadScreenshots(widget.feedback)) {
      return const SizedBox.shrink();
    }
    final loc = AppLocalizations.of(context)!;
    if (_images == null) {
      if (widget.feedback.screenshotsLoaded) return _gallery(context);
      return OutlinedButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.image_search_outlined),
        label: Text(loc.viewFeedbackScreenshots),
      );
    }
    return FutureBuilder<void>(
      future: _images,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context)!.retry),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          );
        }
        return _gallery(context);
      },
    );
  }
}

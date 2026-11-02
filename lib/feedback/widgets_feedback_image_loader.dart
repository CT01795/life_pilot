import 'package:flutter/material.dart';
import 'package:life_pilot/feedback/controller_feedback_admin.dart';
import 'package:life_pilot/feedback/model_feedback.dart';
import 'package:life_pilot/feedback/widgets_feedback_screenshots.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

/// Created only inside the detail dialog, never while building the list.
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
  late Future<void> _images;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _images = widget.controller.loadScreenshots(widget.feedback);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _images,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return TextButton.icon(
          onPressed: () => setState(_load),
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
      return WidgetsFeedbackScreenshots(feedback: widget.feedback);
    },
  );
}

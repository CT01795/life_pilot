import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/feedback/controller_feedback.dart';
import 'package:life_pilot/feedback/model_feedback_submission.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/widgets/widgets_adaptive_button.dart';
import 'package:life_pilot/feedback/service_feedback.dart';
import 'package:provider/provider.dart';

class PageFeedback extends StatelessWidget {
  const PageFeedback({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          ControllerFeedback(ServiceFeedback(), context.read<ControllerAuth>()),
      child: const PageFeedbackBody(),
    );
  }
}

class PageFeedbackBody extends StatelessWidget {
  const PageFeedbackBody({super.key});

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _submit(
    BuildContext context,
    ControllerFeedback controller,
  ) async {
    final result = await controller.submit();
    if (!context.mounted || result == null) return;
    final loc = AppLocalizations.of(context)!;
    final message = switch (result.status) {
      FeedbackSubmissionStatus.sent => loc.feedbackSent,
      FeedbackSubmissionStatus.requiredFields => loc.feedbackRequired,
      FeedbackSubmissionStatus.failed => loc.feedbackSendFailed(
        result.error.toString(),
      ),
    };
    _message(context, message);
    if (result.status == FeedbackSubmissionStatus.sent) Navigator.pop(context);
  }

  Future<void> _capture(
    BuildContext context,
    ControllerFeedback controller,
  ) async {
    final result = await controller.captureScreenshot();
    if (context.mounted && result == false) {
      _message(context, AppLocalizations.of(context)!.unknownError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ControllerFeedback>();
    final loc = AppLocalizations.of(context)!;
    final screenshotCacheSize = (100 * MediaQuery.devicePixelRatioOf(context))
        .round();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(2),
        child: ListView(
          children: [
            TextField(
              enabled: !controller.isSending,
              decoration: InputDecoration(labelText: loc.feedbackPurpose),
              onChanged: (v) => controller.subject = v,
            ),
            TextField(
              enabled: !controller.isSending,
              decoration: InputDecoration(labelText: loc.feedbackContent),
              maxLines: 4,
              onChanged: (v) => controller.content = v,
            ),
            Gaps.h8,
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: AdaptiveButtonLabel(loc.captureScreen),
              onPressed: controller.isSending || controller.isCapturing
                  ? null
                  : () => _capture(context, controller),
            ),
            if (controller.screenshot.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: controller.screenshot
                      .map(
                        (imgBytes) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            imgBytes,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            cacheWidth: screenshotCacheSize,
                            cacheHeight: screenshotCacheSize,
                            filterQuality: FilterQuality.low,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            Gaps.h8,
            ElevatedButton(
              onPressed: controller.isSending || controller.isCapturing
                  ? null
                  : () => _submit(context, controller),
              child: controller.isSending
                  ? const CircularProgressIndicator()
                  : AdaptiveButtonLabel(loc.recordSubmit),
            ),
          ],
        ),
      ),
    );
  }
}

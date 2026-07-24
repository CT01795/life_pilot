import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/pages/home/widgets/dialogs/draggable_resizable_dialog.dart';
import 'package:life_pilot/feedback/controller_feedback.dart';
import 'package:life_pilot/feedback/page_feedback.dart';
import 'package:life_pilot/feedback/service_feedback.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class FeedbackDialog extends StatelessWidget {
  const FeedbackDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return DraggableResizableDialog(
      title: loc.feedback,
      child: ChangeNotifierProvider(
        create: (_) => ControllerFeedback(
          ServiceFeedback(),
          context.read<ControllerAuth>(),
        ),
        child: const PageFeedbackBody(),
      ),
    );
  }
}

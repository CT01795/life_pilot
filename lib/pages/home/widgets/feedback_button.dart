import 'package:flutter/material.dart';
import 'package:life_pilot/pages/home/widgets/dialogs/feedback_dialog.dart';

class FeedbackButton extends StatelessWidget {
  const FeedbackButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.feedback, color: Colors.white),
      tooltip: 'Feedback',
      onPressed: () {
        showDialog(
          context: context,
          // 不要 Flutter 預設黑背景
          barrierColor: Colors.transparent,

          // 允許拖到螢幕邊緣
          useSafeArea: false,
          builder: (_) => const FeedbackDialog(),
        );
      },
    );
  }
}

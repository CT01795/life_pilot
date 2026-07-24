import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/pages/home/widgets/dialogs/draggable_resizable_dialog.dart';
import 'package:life_pilot/feedback/controller_feedback.dart';
import 'package:life_pilot/feedback/page_feedback.dart';
import 'package:life_pilot/feedback/service_feedback.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:provider/provider.dart';

class UserMenuButton extends StatelessWidget {
  const UserMenuButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final auth = context.watch<ModelAuthView>();
    if (auth.account == null || auth.account!.isEmpty) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.account_circle,
        color: Colors.white,
      ),
      tooltip: loc.userMenuButton,
      color: const Color(0xFF0066CC), // 改成跟 LanguageToggleDropdown 一樣
      onSelected: (value) {
        switch (value) {
          case "feedback":
            _openFeedback(context);
            break;
          case "logout":
            auth.logout.call();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: "account",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                auth.account!.contains('@') ? auth.account!.split('@')[0] : auth.account!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                auth.account!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: "feedback",
          child: Row(
            children: [
              Icon(Icons.feedback, color: Colors.white),
              Gaps.w8,
              Text(
                loc.feedback,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: "logout",
          child: Row(
            children: [
              const Icon(
                Icons.exit_to_app,
                color: Colors.white
              ),
              Gaps.w8,
              Text(
                loc.logout,
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openFeedback(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) {
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
      },
    );
  }
}

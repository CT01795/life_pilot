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
import 'package:url_launcher/url_launcher.dart';

class UserMenuButton extends StatelessWidget {
  const UserMenuButton({
    super.key,
  });

  static final Uri _privacyPolicyUrl = Uri.parse(
    'https://ct01795.github.io/life_pilot/privacy.html',
  );
  static final Uri _termsOfServiceUrl = Uri.parse(
    'https://ct01795.github.io/life_pilot/terms.html',
  );

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
          case "privacyPolicy":
            _openLink(context, _privacyPolicyUrl);
            break;
          case "termsOfService":
            _openLink(context, _termsOfServiceUrl);
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
                auth.account!.contains('@')
                    ? auth.account!.split('@')[0]
                    : auth.account!,
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
        const PopupMenuDivider(),
        PopupMenuItem(
          value: "privacyPolicy",
          child: Row(
            children: [
              const Icon(Icons.privacy_tip_outlined, color: Colors.white),
              Gaps.w8,
              Text(
                loc.privacyPolicy,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: "termsOfService",
          child: Row(
            children: [
              const Icon(Icons.description_outlined, color: Colors.white),
              Gaps.w8,
              Text(
                loc.termsOfService,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: "logout",
          child: Row(
            children: [
              const Icon(Icons.exit_to_app, color: Colors.white),
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

  Future<void> _openLink(BuildContext context, Uri url) async {
    if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Unable to open the link. Please try again.')),
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

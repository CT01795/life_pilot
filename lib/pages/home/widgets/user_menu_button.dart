import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/auth/page_account_security.dart';
import 'package:life_pilot/apps/page_module_authorization.dart';
import 'package:life_pilot/apps/page_settings.dart';
import 'package:life_pilot/pages/home/widgets/dialogs/draggable_resizable_dialog.dart';
import 'package:life_pilot/pages/home/widgets/dialogs/legal_document_dialog.dart';
import 'package:life_pilot/feedback/controller_feedback.dart';
import 'package:life_pilot/feedback/page_feedback.dart';
import 'package:life_pilot/feedback/service_feedback.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/page_subscription_plans.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/service/export/service_export_platform.dart';
import 'package:life_pilot/utils/service/service_personal_data.dart';
import 'package:provider/provider.dart';

class UserMenuButton extends StatelessWidget {
  const UserMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final auth = context.watch<ModelAuthView>();
    final isSysAdmin = context.select<ControllerAuth, bool>(
      (controller) => controller.isSysAdmin,
    );
    final isVendor = context.select<ControllerAuth, bool>(
      (controller) => controller.isVendor,
    );
    if (auth.account == null || auth.account!.isEmpty) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      icon: const Icon(Icons.account_circle, color: Colors.white),
      tooltip: loc.userMenuButton,
      color: const Color(0xFF0066CC), // 改成跟 LanguageToggleDropdown 一樣
      constraints: const BoxConstraints(minWidth: 320, maxWidth: 360),
      onSelected: (value) async {
        switch (value) {
          case "feedback":
            _openFeedback(context);
            break;
          case "privacyPolicy":
            _openLegalDocument(context, assetPath: 'web/privacy.html');
            break;
          case "termsOfService":
            _openLegalDocument(context, assetPath: 'web/terms.html');
            break;
          case "dataStorage":
            await showDialog<void>(
              context: context,
              builder: (dialogContext) => Dialog(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 560,
                    maxHeight: 680,
                  ),
                  child: const PageSettings(closeOnStorageChange: true),
                ),
              ),
            );
            break;
          case "moduleAuthorization":
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PageModuleAuthorization(),
              ),
            );
            break;
          case "subscriptionPlans":
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PageSubscriptionPlans(),
              ),
            );
            break;
          case "accountSecurity":
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PageAccountSecurity(),
              ),
            );
            break;
          case "requestDataExport":
            _requestDataExport(context, auth.account!, loc);
            break;
          case "logout":
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(loc.logout),
                content: Text(loc.logoutConfirmation),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(loc.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(loc.logout),
                  ),
                ],
              ),
            );
            if (confirmed != true) break;
            final error = await auth.logout();
            if (error != null && context.mounted) {
              AppNavigator.showErrorBar(
                auth.showLoginError(message: error, loc: loc),
              );
            }
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
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: "accountSecurity",
          child: Row(
            children: [
              const Icon(Icons.security_outlined, color: Colors.white),
              Gaps.w8,
              Text(
                loc.accountSecurity,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        if (!isVendor)
          PopupMenuItem(
            value: "subscriptionPlans",
            child: Row(
              children: [
                const Icon(
                  Icons.workspace_premium_outlined,
                  color: Colors.white,
                ),
                Gaps.w8,
                Expanded(
                  child: Text(
                    loc.subscriptionPlansTitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        if (!isVendor) ...[
          PopupMenuItem(
            value: "dataStorage",
            child: Row(
              children: [
                const Icon(Icons.storage_outlined, color: Colors.white),
                Gaps.w8,
                Expanded(
                  child: Text(
                    loc.dataStorageTitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: "requestDataExport",
            child: Row(
              children: [
                const Icon(Icons.file_download_outlined, color: Colors.white),
                Gaps.w8,
                Expanded(
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      loc.accountMenuDataExport,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        PopupMenuItem(
          value: "feedback",
          child: Row(
            children: [
              const Icon(Icons.feedback_outlined, color: Colors.white),
              Gaps.w8,
              Text(loc.feedback, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
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
        if (isSysAdmin)
          PopupMenuItem(
            value: "moduleAuthorization",
            child: Row(
              children: [
                const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Colors.white,
                ),
                Gaps.w8,
                Expanded(
                  child: Text(
                    loc.moduleAuthorization,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: "logout",
          child: Row(
            children: [
              const Icon(Icons.logout_outlined, color: Colors.white),
              Gaps.w8,
              Text(loc.logout, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  void _openLegalDocument(BuildContext context, {required String assetPath}) {
    showDialog(
      context: context,
      builder: (_) => LegalDocumentDialog(assetPath: assetPath),
    );
  }

  Future<void> _requestDataExport(
    BuildContext context,
    String account,
    AppLocalizations loc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.requestDataExport),
        content: Text(loc.dataExportRequestDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.continueLabel),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final path = await ServicePersonalData().export(
        email: account,
        exporter: context.read<ServiceExportPlatform>(),
        loc: loc,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.dataExportCompleted(path))));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.dataExportFailed(error.toString()))),
      );
    }
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

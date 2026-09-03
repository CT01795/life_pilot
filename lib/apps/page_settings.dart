import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/local_storage/service_local_data_transfer.dart';
import 'package:life_pilot/local_storage/widgets_data_storage_choice.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/subscription/widgets_admin_subscription_editor.dart';

class PageSettings extends StatefulWidget {
  const PageSettings({this.closeOnStorageChange = false, super.key});

  final bool closeOnStorageChange;

  @override
  State<PageSettings> createState() => _PageSettingsState();
}

class _PageSettingsState extends State<PageSettings> {
  bool _transferring = false;

  Future<void> _move({required bool upload}) async {
    if (_transferring) return;
    final auth = context.read<ControllerAuth>();
    final account = auth.currentAccount;
    if (account == null) return;
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
                upload ? loc.dataUploadToCloudAction : loc.dataMoveToLocal),
            content: Text(upload
                ? loc.dataUploadToCloudConfirm
                : loc.dataMoveToLocalConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(loc.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(loc.confirm),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _transferring = true);
    final service = ServiceLocalDataTransfer();
    final result = upload
        ? await service.uploadLocalToCloud(account)
        : await service.moveCloudToLocal(account);
    if (!mounted) return;
    setState(() => _transferring = false);
    if (!upload && result.succeeded) {
      await auth.setPreferredStorage(DataStorageLocation.local);
    } else if (upload && result.succeeded) {
      await auth.setPreferredStorage(DataStorageLocation.cloud);
    }
    if (result.succeeded) {
      AppNavigator.showSnackBar(
        upload ? loc.dataUploadToCloudSuccess : loc.dataMoveToLocalSuccess,
      );
      if (widget.closeOnStorageChange && mounted) {
        Navigator.of(context).pop();
      }
      return;
    }
    final friendlyMessage = upload
        ? _uploadFailureMessage(loc, result.failureReason)
        : loc.dataMoveToLocalFailed;
    final rawReason = result.failureReason?.trim();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
            upload ? loc.dataUploadToCloudFailed : loc.dataMoveToLocalFailed),
        content: SingleChildScrollView(
          child: SelectableText(
            rawReason == null || rawReason.isEmpty
                ? friendlyMessage
                : '$friendlyMessage\n\n$rawReason',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(loc.close),
          ),
        ],
      ),
    );
  }

  String _uploadFailureMessage(AppLocalizations loc, String? reason) {
    final match = RegExp(
      r'local_upload_quota_exceeded:([^:]+):(\d+):(\d+):(\d+)',
    ).firstMatch(reason ?? '');
    if (match == null) return loc.dataUploadToCloudFailed;
    return loc.dataUploadQuotaExceeded(
      match.group(1)!,
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final auth = context.watch<ControllerAuth>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(loc.settings, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        DataStorageChoice(
          value: auth.preferredStorage,
          onChanged: auth.isAnonymous
              ? null
              : (value) {
                  if (value == auth.preferredStorage) return;
                  _move(upload: value == DataStorageLocation.cloud);
                },
        ),
        if (auth.isSysAdmin) ...[
          const SizedBox(height: 12),
          const AdminSubscriptionEditor(),
        ],
        if (_transferring) ...[
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}

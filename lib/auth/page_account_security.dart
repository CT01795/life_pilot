import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/auth/service_auth.dart';
import 'package:life_pilot/auth/service_account_security.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/widgets_admin_account_deletion_requests.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/service/service_api.dart';
import 'package:life_pilot/utils/service/service_personal_data.dart';
import 'package:life_pilot/utils/widgets/widgets_adaptive_button.dart';
import 'package:provider/provider.dart';

class PageAccountSecurity extends StatefulWidget {
  const PageAccountSecurity({super.key});

  @override
  State<PageAccountSecurity> createState() => _PageAccountSecurityState();
}

class _PageAccountSecurityState extends State<PageAccountSecurity> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _adminUserEmail = TextEditingController();
  final _service = ServiceAccountSecurity();
  bool _busy = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _temporaryPassword;
  String _adminAccountType = 'personal';

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    _adminUserEmail.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final loc = AppLocalizations.of(context)!;
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await _service.changePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      AppNavigator.showSnackBar(loc.changePasswordSuccessful);
    } on AccountPasswordException catch (error) {
      AppNavigator.showErrorBar(_passwordErrorMessage(loc, error.failure));
    } catch (_) {
      AppNavigator.showErrorBar(loc.changePasswordFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _passwordErrorMessage(
    AppLocalizations loc,
    AccountPasswordFailure failure,
  ) {
    return switch (failure) {
      AccountPasswordFailure.noSignedInUser => loc.changePasswordFailed,
      AccountPasswordFailure.incorrectCurrentPassword =>
        loc.currentPasswordIncorrect,
      AccountPasswordFailure.sameAsCurrent => loc.passwordMustBeDifferent,
      AccountPasswordFailure.weakPassword => loc.passwordDoesNotMeetPolicy,
      AccountPasswordFailure.reauthenticationRequired =>
        loc.passwordReauthenticationRequired,
      AccountPasswordFailure.unknown => loc.changePasswordFailed,
    };
  }

  Future<void> _sendResetEmail() async {
    final loc = AppLocalizations.of(context)!;
    if (_busy) return;
    final account = ServiceAuth.currentAccount();
    if (account == null || account.isEmpty) {
      AppNavigator.showErrorBar(loc.noEmailError);
      return;
    }
    setState(() => _busy = true);
    try {
      final error = await ServiceAuth.resetPassword(email: account);
      if (error == null) {
        AppNavigator.showSnackBar(loc.resetPasswordEmail);
      } else {
        AppNavigator.showErrorBar(loc.resetPasswordError);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _contactAdministrator() async {
    final loc = AppLocalizations.of(context)!;
    final account = ServiceAuth.currentAccount();
    if (_busy || account == null || account.isEmpty) return;
    final opened = await _service.contactAdministrator(
      subject: loc.adminPasswordHelpSubject,
      body: loc.adminPasswordHelpBody(account),
    );
    if (!mounted) return;
    if (opened) {
      AppNavigator.showSnackBar(loc.adminPasswordHelpOpened);
    } else {
      AppNavigator.showErrorBar(
        loc.adminPasswordHelpEmailUnavailable(
          ServiceAccountSecurity.administratorEmail,
        ),
      );
    }
  }

  Future<void> _createTemporaryPassword() async {
    final loc = AppLocalizations.of(context)!;
    final auth = context.read<ControllerAuth>();
    final email = _adminUserEmail.text.trim();
    if (_busy || !auth.isSysAdmin) return;
    if (email.isEmpty || !email.contains('@')) {
      AppNavigator.showErrorBar(loc.invalidEmail);
      return;
    }

    setState(() => _busy = true);
    try {
      final password = await _service.createTemporaryPasswordForUser(email);
      if (!mounted) return;
      setState(() => _temporaryPassword = password);
      AppNavigator.showSnackBar(loc.adminTemporaryPasswordCreated(email));
    } on ServiceApiException catch (error) {
      if (!mounted) return;
      AppNavigator.showErrorBar(
        error.statusCode == 404
            ? loc.adminPasswordResetUserNotFound
            : loc.adminPasswordResetFailed,
      );
    } catch (_) {
      if (mounted) AppNavigator.showErrorBar(loc.adminPasswordResetFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createUserAccount() async {
    final loc = AppLocalizations.of(context)!;
    final auth = context.read<ControllerAuth>();
    final email = _adminUserEmail.text.trim();
    if (_busy || !auth.isSysAdmin) return;
    if (email.isEmpty || !email.contains('@')) {
      AppNavigator.showErrorBar(loc.invalidEmail);
      return;
    }

    setState(() => _busy = true);
    try {
      final password = await _service.createAccountForUser(
        email: email,
        accountType: _adminAccountType,
      );
      if (!mounted) return;
      setState(() => _temporaryPassword = password);
      AppNavigator.showSnackBar(loc.adminAccountCreateSuccessful(email));
    } on ServiceApiException catch (error) {
      if (!mounted) return;
      AppNavigator.showErrorBar(
        error.statusCode == 409
            ? loc.adminAccountCreateAlreadyExists
            : loc.adminAccountCreateFailed,
      );
    } catch (_) {
      if (mounted) AppNavigator.showErrorBar(loc.adminAccountCreateFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyTemporaryPassword() async {
    final loc = AppLocalizations.of(context)!;
    final password = _temporaryPassword;
    if (password == null) return;
    await Clipboard.setData(ClipboardData(text: password));
    if (mounted) AppNavigator.showSnackBar(loc.adminTemporaryPasswordCopied);
  }

  Future<void> _requestAccountDeletion() async {
    final loc = AppLocalizations.of(context)!;
    if (_busy) return;
    final auth = context.read<ControllerAuth>();
    if (auth.storesNewDataLocally) {
      AppNavigator.showErrorBar(loc.accountDeletionCloudOnly);
      return;
    }
    setState(() => _busy = true);
    try {
      final existing = await ServicePersonalData()
          .fetchMyAccountDeletionRequest();
      if (!mounted) return;
      final status = existing?['status']?.toString();
      if (status == 'pending') {
        await _showPendingDeletionRequest(loc);
        return;
      }
      if (status == 'cancel_pending') {
        AppNavigator.showSnackBar(loc.accountDeletionCancellationPending);
        return;
      }
    } catch (error) {
      if (mounted) {
        AppNavigator.showErrorBar(loc.accountDeletionFailed(error.toString()));
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.requestAccountDeletion),
        content: Text(loc.accountDeletionRequestDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(loc.continueLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ServicePersonalData().requestAccountDeletion();
      if (mounted) AppNavigator.showSnackBar(loc.accountDeletionCompleted);
    } catch (error) {
      if (!mounted) return;
      final errorText = error.toString();
      AppNavigator.showErrorBar(
        errorText.contains('deletion_request_already_pending')
            ? loc.accountDeletionPending
            : loc.accountDeletionFailed(errorText),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showPendingDeletionRequest(AppLocalizations loc) async {
    final cancelRequest = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.accountDeletionPending),
        content: Text(loc.accountDeletionPendingDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.close),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(loc.accountDeletionCancelRequest),
          ),
        ],
      ),
    );
    if (cancelRequest != true || !mounted) return;
    try {
      await ServicePersonalData().requestAccountDeletionCancellation();
      if (mounted) {
        AppNavigator.showSnackBar(loc.accountDeletionCancellationSubmitted);
      }
    } catch (error) {
      if (mounted) {
        AppNavigator.showErrorBar(loc.accountDeletionFailed(error.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isSysAdmin = context.select<ControllerAuth, bool>(
      (auth) => auth.isSysAdmin,
    );
    return Scaffold(
      appBar: AppBar(title: Text(loc.accountSecurity)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      loc.changePassword,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Gaps.h16,
                    _passwordField(
                      controller: _currentPassword,
                      label: loc.currentPassword,
                      obscure: _obscureCurrent,
                      onToggle: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                    Gaps.h12,
                    _passwordField(
                      controller: _newPassword,
                      label: loc.newPassword,
                      obscure: _obscureNew,
                      onToggle: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                    Gaps.h12,
                    _passwordField(
                      controller: _confirmPassword,
                      label: loc.confirmPassword,
                      obscure: _obscureConfirm,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      confirmation: true,
                    ),
                    Gaps.h16,
                    FilledButton.icon(
                      onPressed: _busy ? null : _changePassword,
                      icon: const Icon(Icons.password_outlined),
                      label: AdaptiveButtonLabel(loc.changePassword),
                    ),
                    Gaps.h32,
                    const Divider(),
                    Gaps.h16,
                    Text(
                      loc.passwordHelpTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Gaps.h8,
                    Text(loc.passwordHelpDescription),
                    Gaps.h16,
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _sendResetEmail,
                      icon: const Icon(Icons.mark_email_read_outlined),
                      label: AdaptiveButtonLabel(loc.resetByEmailVerification),
                    ),
                    Gaps.h8,
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _contactAdministrator,
                      icon: const Icon(Icons.support_agent_outlined),
                      label: AdaptiveButtonLabel(loc.askAdministrator),
                    ),
                    if (isSysAdmin) ...[
                      Gaps.h32,
                      const Divider(),
                      Gaps.h16,
                      Text(
                        loc.adminPasswordResetTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Gaps.h8,
                      Text(loc.adminPasswordResetDescription),
                      Gaps.h16,
                      TextField(
                        controller: _adminUserEmail,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: loc.adminPasswordResetUserEmail,
                          prefixIcon: const Icon(Icons.alternate_email),
                        ),
                        onChanged: (_) {
                          if (_temporaryPassword != null) {
                            setState(() => _temporaryPassword = null);
                          }
                        },
                      ),
                      Gaps.h12,
                      DropdownButtonFormField<String>(
                        initialValue: _adminAccountType,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: loc.adminAccountCreateAccountType,
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'personal',
                            child: Text(loc.personalAccountTitle),
                          ),
                          DropdownMenuItem(
                            value: 'vendor',
                            child: Text(loc.vendorRegistrationTitle),
                          ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(
                                () => _adminAccountType = value ?? 'personal',
                              ),
                      ),
                      Gaps.h12,
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _busy ? null : _createUserAccount,
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                            label: AdaptiveButtonLabel(
                              loc.adminAccountCreateAction,
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _busy ? null : _createTemporaryPassword,
                            icon: const Icon(Icons.password_outlined),
                            label: AdaptiveButtonLabel(
                              loc.adminPasswordResetSend,
                            ),
                          ),
                        ],
                      ),
                      if (_temporaryPassword case final password?) ...[
                        Gaps.h16,
                        Card(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  loc.adminTemporaryPasswordLabel,
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                Gaps.h8,
                                SelectableText(
                                  password,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                Gaps.h8,
                                Text(loc.adminTemporaryPasswordInstruction),
                                Gaps.h12,
                                OutlinedButton.icon(
                                  onPressed: _copyTemporaryPassword,
                                  icon: const Icon(Icons.copy_outlined),
                                  label: AdaptiveButtonLabel(
                                    loc.adminTemporaryPasswordCopy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                    Gaps.h32,
                    const Divider(),
                    Gaps.h16,
                    Tooltip(
                      message: loc.accountDeletionAdminReviewHint,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _requestAccountDeletion,
                        icon: const Icon(Icons.person_remove_outlined),
                        label: AdaptiveButtonLabel(
                          loc.accountMenuAccountDeletion,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                    if (_busy) ...[
                      Gaps.h16,
                      const Center(child: CircularProgressIndicator()),
                    ],
                    if (isSysAdmin) ...[
                      Gaps.h32,
                      const Divider(),
                      Gaps.h16,
                      const AdminAccountDeletionRequests(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    bool confirmation = false,
  }) {
    final loc = AppLocalizations.of(context)!;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: [
        controller == _currentPassword
            ? AutofillHints.password
            : AutofillHints.newPassword,
      ],
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          onPressed: onToggle,
          tooltip: obscure ? loc.showPassword : loc.hidePassword,
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
        ),
      ),
      validator: (value) {
        final password = value ?? '';
        if (password.isEmpty) return loc.noPasswordError;
        if (!confirmation &&
            controller == _newPassword &&
            password.length < AuthConstants.minimumPasswordLength) {
          return loc.weakPassword;
        }
        if (!confirmation &&
            controller == _newPassword &&
            password == _currentPassword.text) {
          return loc.passwordMustBeDifferent;
        }
        if (confirmation && password != _newPassword.text) {
          return loc.passwordMismatch;
        }
        return null;
      },
    );
  }
}

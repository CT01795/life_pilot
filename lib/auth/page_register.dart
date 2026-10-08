import 'package:flutter/material.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/auth/service_account_security.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/widgets/dialogs/legal_document_dialog.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/widgets/widgets_language_toggle_dropdown.dart';
import 'package:provider/provider.dart';

class PageRegister extends StatefulWidget {
  const PageRegister({super.key});

  @override
  State<PageRegister> createState() => _PageRegisterState();
}

class _PageRegisterState extends State<PageRegister> {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final FocusNode _emailFocusNode;
  late final FocusNode _passwordFocusNode;
  late final FocusNode _confirmPasswordFocusNode;
  late final ModelAuthView _authView; // ✅ 改用 Model 層來管理 ControllerAuth

  late bool _initialized;
  late bool _hasAcceptedLegalTerms;
  late bool _hasReadPrivacyPolicy;
  late bool _hasReadTermsOfService;
  late bool _isSubmitting;
  late bool _obscurePassword;
  late bool _obscureConfirmPassword;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _emailFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
    _confirmPasswordFocusNode = FocusNode();
    _initialized = false;
    _hasAcceptedLegalTerms = false;
    _hasReadPrivacyPolicy = false;
    _hasReadTermsOfService = false;
    _isSubmitting = false;
    _obscurePassword = true;
    _obscureConfirmPassword = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _authView = context.read<ModelAuthView>(); // ✅ 使用 Model 來統一處理狀態
      _emailController.text = _authView.getRegisterEmail() ?? '';
      _emailController.text = _authView.getRegisterEmail() ?? '';
      _initialized = true;
      _hasAcceptedLegalTerms = false;
    }
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _tryRegister(AppLocalizations loc) async {
    if (!mounted || _isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_hasAcceptedLegalTerms) {
      AppNavigator.showErrorBar(loc.acceptLegalTermsRequired);
      return;
    }
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() => _isSubmitting = true);

    String? error;
    try {
      error = await _authView.register(email: email, password: password);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    if (error == null) {
      AppNavigator.showSnackBar(
        _authView.isLoggedIn
            ? loc.registrationSuccessful
            : loc.registrationVerificationRequired,
      );
      return;
    }

    if (mounted && error.isNotEmpty) {
      if (error == ErrorFields.emailRateLimitExceededError) {
        await _requestAdministratorApproval(loc, email);
        return;
      }
      AppNavigator.showErrorBar(
        _authView.showLoginError(message: error, loc: loc),
      );
    }
  }

  Future<void> _requestAdministratorApproval(
    AppLocalizations loc,
    String email,
  ) async {
    final accountType = _authView.registrationAccountType == 'vendor'
        ? loc.vendorRegistrationTitle
        : loc.personalAccountTitle;
    final contact =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(loc.registrationAdminApprovalTitle),
            content: Text(loc.registrationAdminApprovalDescription),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(loc.cancel),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.forward_to_inbox_outlined),
                label: Text(loc.registrationAdminApprovalAction),
              ),
            ],
          ),
        ) ??
        false;
    if (!contact || !mounted) return;
    final opened = await ServiceAccountSecurity().contactAdministrator(
      subject: loc.registrationAdminApprovalSubject,
      body: loc.registrationAdminApprovalBody(email, accountType),
    );
    if (!mounted) return;
    if (opened) {
      AppNavigator.showSnackBar(loc.registrationAdminApprovalOpened);
    } else {
      AppNavigator.showErrorBar(
        loc.adminPasswordHelpEmailUnavailable(
          ServiceAccountSecurity.administratorEmail,
        ),
      );
    }
  }

  void _goBack() {
    _authView.goBackToLogin(_emailController.text.trim());
  }

  void _openLegalDocument({
    required String assetPath,
    required VoidCallback onReadComplete,
  }) {
    showDialog(
      context: context,
      builder: (_) => LegalDocumentDialog(
        assetPath: assetPath,
        onReadComplete: onReadComplete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.appTitle),
        actions: [
          Tooltip(message: loc.language, child: LanguageToggleDropdown()),
        ],
      ),
      body: SingleChildScrollView(
        padding: Insets.all12,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  children: [
                    if (_authView.registrationAccountType == 'vendor') ...[
                      Card(
                        elevation: 0,
                        color: Theme.of(
                          context,
                        ).colorScheme.secondaryContainer.withValues(alpha: 0.6),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.storefront_outlined),
                                  Gaps.w8,
                                  Expanded(
                                    child: Text(
                                      loc.vendorRegistrationTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              Gaps.h4,
                              Text(loc.vendorRegistrationDescription),
                              Gaps.h12,
                              _vendorRegistrationBenefit(
                                Icons.rocket_launch_outlined,
                                loc.vendorRegistrationFreeStart,
                              ),
                              _vendorRegistrationBenefit(
                                Icons.fact_check_outlined,
                                loc.vendorSubmissionBenefitReview,
                              ),
                              _vendorRegistrationBenefit(
                                Icons.insights_outlined,
                                loc.vendorRegistrationAnalytics,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Gaps.h12,
                    ],
                    TextFormField(
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      textCapitalization:
                          TextCapitalization.none, //避免 email 被自動大寫
                      keyboardType: TextInputType.emailAddress, //email 鍵盤類型
                      obscureText: false,
                      decoration: InputDecoration(labelText: loc.email),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return loc.noEmailError;
                        if (!_emailPattern.hasMatch(email)) {
                          return loc.invalidEmail;
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        _passwordFocusNode.requestFocus(); // 跳到下一個輸入欄
                      },
                    ),
                    Gaps.h16,
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      autofillHints: const [AutofillHints.newPassword],
                      autocorrect: false,
                      enableSuggestions: false,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: loc.password,
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? loc.showPassword
                              : loc.hidePassword,
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final password = value ?? '';
                        if (password.isEmpty) return loc.noPasswordError;
                        if (password.length <
                            AuthConstants.minimumPasswordLength) {
                          return loc.weakPassword;
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        _confirmPasswordFocusNode.requestFocus();
                      },
                    ),
                    Gaps.h16,
                    TextFormField(
                      controller: _confirmPasswordController,
                      focusNode: _confirmPasswordFocusNode,
                      autofillHints: const [AutofillHints.newPassword],
                      autocorrect: false,
                      enableSuggestions: false,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: loc.confirmPassword,
                        suffixIcon: IconButton(
                          tooltip: _obscureConfirmPassword
                              ? loc.showPassword
                              : loc.hidePassword,
                          onPressed: () {
                            setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            );
                          },
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '') != _passwordController.text) {
                          return loc.passwordMismatch;
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) async {
                        await _tryRegister(loc);
                      },
                    ),
                    Gaps.h16,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 48,
                          child: Center(
                            child: Checkbox(
                              value: _hasAcceptedLegalTerms,
                              onChanged: (value) {
                                if (!mounted) return;
                                if (value == true &&
                                    (!_hasReadPrivacyPolicy ||
                                        !_hasReadTermsOfService)) {
                                  AppNavigator.showErrorBar(
                                    loc.readLegalTermsRequired,
                                  );
                                  return;
                                }
                                setState(() {
                                  _hasAcceptedLegalTerms = value ?? false;
                                });
                              },
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: Insets.directionalT6,
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(loc.agreeToLegalTermsPrefix),
                                TextButton(
                                  onPressed: () {
                                    _openLegalDocument(
                                      assetPath: 'web/privacy.html',
                                      onReadComplete: () {
                                        if (!mounted || _hasReadPrivacyPolicy) {
                                          return;
                                        }
                                        setState(
                                          () => _hasReadPrivacyPolicy = true,
                                        );
                                      },
                                    );
                                  },
                                  child: Text(loc.privacyPolicy),
                                ),
                                if (_hasReadPrivacyPolicy) ...[
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  Gaps.w8,
                                ],
                                Text(loc.legalTermsConnector),
                                TextButton(
                                  onPressed: () {
                                    _openLegalDocument(
                                      assetPath: 'web/terms.html',
                                      onReadComplete: () {
                                        if (!mounted ||
                                            _hasReadTermsOfService) {
                                          return;
                                        }
                                        setState(
                                          () => _hasReadTermsOfService = true,
                                        );
                                      },
                                    );
                                  },
                                  child: Text(loc.termsOfService),
                                ),
                                if (_hasReadTermsOfService) ...[
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  Gaps.w8,
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Gaps.h16,
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () async {
                                  await _tryRegister(loc);
                                },
                          child: _isSubmitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(loc.register),
                        ),
                        TextButton(onPressed: _goBack, child: Text(loc.back)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _vendorRegistrationBenefit(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Icon(icon, size: 18),
        Gaps.w8,
        Expanded(child: Text(text)),
      ],
    ),
  );
}

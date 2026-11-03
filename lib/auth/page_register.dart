import 'package:flutter/material.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/auth/service_account_security.dart';
import 'package:life_pilot/auth/controller_account_mail_request.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/widgets/dialogs/legal_document_dialog.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/widgets/widgets_language_toggle_dropdown.dart';
import 'package:provider/provider.dart';

class PageRegister extends StatefulWidget {
  const PageRegister({super.key, this.security});
  final ServiceAccountSecurity? security;

  @override
  State<PageRegister> createState() => _PageRegisterState();
}

class _PageRegisterState extends State<PageRegister> {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  late final TextEditingController _emailController;
  late final _requests = ControllerAccountMailRequest(
    service: widget.security ?? ServiceAccountSecurity(),
  );
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final FocusNode _emailFocusNode;
  late final ModelAuthView _authView; // ✅ 改用 Model 層來管理 ControllerAuth

  late bool _initialized;
  late bool _hasAcceptedLegalTerms;
  late bool _hasReadPrivacyPolicy;
  late bool _hasReadTermsOfService;
  late bool _isSubmitting;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _emailFocusNode = FocusNode();
    _initialized = false;
    _hasAcceptedLegalTerms = false;
    _hasReadPrivacyPolicy = false;
    _hasReadTermsOfService = false;
    _isSubmitting = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _authView = context.read<ModelAuthView>(); // ✅ 使用 Model 來統一處理狀態
      _emailController.text = _authView.getRegisterEmail() ?? '';
      _initialized = true;
      _hasAcceptedLegalTerms = false;
    }
  }

  @override
  void dispose() {
    _requests.dispose();
    _emailFocusNode.dispose();
    _emailController.dispose();
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
    setState(() => _isSubmitting = true);
    try {
      final accountType = _authView.registrationAccountType == 'vendor'
          ? loc.vendorRegistrationTitle
          : loc.personalAccountTitle;
      final result = await _requests.send(
        email: email,
        subject: loc.registrationAdminApprovalSubject,
        body: loc.registrationAdminApprovalBody(accountType),
        checkRegistrationEligibility: true,
      );
      if (!mounted || result == null) return;
      if (result == AccountMailRequestResult.opened) {
        AppNavigator.showSnackBar(loc.registrationAdminApprovalOpened);
      } else if (result == AccountMailRequestResult.disabled) {
        AppNavigator.showErrorBar(loc.accountDisabled);
      } else if (result == AccountMailRequestResult.registered) {
        AppNavigator.showErrorBar(loc.emailAlreadyInUse);
      } else if (result == AccountMailRequestResult.statusUnavailable) {
        AppNavigator.showErrorBar(loc.networkError);
      } else {
        AppNavigator.showErrorBar(
          result == AccountMailRequestResult.invalidEmail
              ? loc.invalidEmail
              : loc.adminPasswordHelpEmailUnavailable(
                  ServiceAccountSecurity.administratorEmail,
                ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _tryRegister(loc),
                    ),
                    Gaps.h16,
                    Text(loc.registrationAdminApprovalDescription),
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
                              : Text(loc.registrationAdminApprovalAction),
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

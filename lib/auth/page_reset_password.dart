import 'package:flutter/material.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/utils/widgets/widgets_language_toggle_dropdown.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

class PageResetPassword extends StatefulWidget {
  const PageResetPassword({super.key});

  @override
  State<PageResetPassword> createState() => _PageResetPasswordState();
}

class _PageResetPasswordState extends State<PageResetPassword> {
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final FocusNode _passwordFocusNode;
  late final FocusNode _confirmPasswordFocusNode;
  late bool _initialized;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late final ModelAuthView _authView; // ✅ 改用 Model 層來管理 ControllerAuth

  @override
  void initState() {
    super.initState();
    _initialized = false;
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _passwordFocusNode = FocusNode();
    _confirmPasswordFocusNode = FocusNode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _authView = context.read<ModelAuthView>(); // ✅ 使用 Model 來統一處理狀態
      _initialized = true;
    } // ✅ 使用 Model 來統一處理狀態
  }

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword(AppLocalizations loc) async {
    if (!mounted || _isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final password = _passwordController.text;

    final user = supabase.auth.currentSession?.user;
    logger.i(
      'Reset target present: ${user != null}',
    );
    if (user == null) {
      AppNavigator.showErrorBar(_authView.showLoginError(
          message: ErrorFields.noRecoverySession, loc: loc));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await supabase.auth.updateUser(
        UserAttributes(
          password: password,
        ),
      );
      if (!mounted) {
        return;
      }
      final logoutError = await _authView.logout();
      if (logoutError != null) {
        AppNavigator.showErrorBar(
          _authView.showLoginError(message: logoutError, loc: loc),
        );
        return;
      }
      AppNavigator.showSnackBar(loc.passwordUpdateSuccessful);
    } catch (e) {
      logger.e('Reset Password Error: $e');
      AppNavigator.showErrorBar(_authView.showLoginError(
          message: ErrorFields.resetPasswordError, loc: loc));
      return;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _goBack() async {
    if (!mounted || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final error = await _authView.logout();
      if (error != null && mounted) {
        final loc = AppLocalizations.of(context)!;
        AppNavigator.showErrorBar(
          _authView.showLoginError(message: error, loc: loc),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.appTitle), actions: [
        Tooltip(
          message: loc.language,
          child: LanguageToggleDropdown(),
        ),
      ]),
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
                                () => _obscurePassword = !_obscurePassword);
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
                        await _updatePassword(loc);
                      },
                    ),
                    Gaps.h16,
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () async {
                                  await _updatePassword(loc);
                                },
                          child: _isSubmitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.0),
                                )
                              : Text(loc.updatePassword),
                        ),
                        Gaps.w8,
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () async {
                                  await _goBack();
                                },
                          child: Text(loc.back),
                        ),
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
}

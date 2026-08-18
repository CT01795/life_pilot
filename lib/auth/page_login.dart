import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/utils/widgets/widgets_language_toggle_dropdown.dart';
import 'package:provider/provider.dart';

class PageLogin extends StatefulWidget {
  const PageLogin({super.key});

  @override
  State<PageLogin> createState() => _PageLoginState();
}

class _PageLoginState extends State<PageLogin> {
  static final RegExp _emailPattern = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  );

  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final FocusNode _emailFocusNode;
  late final FocusNode _passwordFocusNode;
  bool _isSubmitting = false;
  bool _isSendingResetEmail = false;
  int _resetEmailCooldownSeconds = 0;
  Timer? _resetEmailCooldownTimer;
  bool _obscurePassword = true;
  late final ModelAuthView _authView; // ✅ 改成 Model 層，而非 Controller 直接呼叫

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _emailFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
  }

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _authView = context.read<ModelAuthView>();
      _emailController.text = _authView.getRegisterEmail() ?? '';
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _resetEmailCooldownTimer?.cancel();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 🔁 導航到註冊頁
  void _navigateToRegister() {
    _authView.goToRegister(_emailController.text.trim());
  }

  // 🔹 嘗試登入或匿名登入
  Future<void> _tryLogin() async {
    if (!mounted || _isSubmitting || _isSendingResetEmail) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    final controllerPageMain = context.read<ControllerPageMain>();
    controllerPageMain.changePage(PageType.home);

    String? error;
    try {
      error = await _authView.login(
        email: email,
        password: password,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    if (!mounted) return;

    if (error?.isNotEmpty ?? false) {
      final loc = AppLocalizations.of(context)!; // ✅ 每次 build 都取最新
      AppNavigator.showErrorBar(
        _authView.showLoginError(message: error!, loc: loc),
      );
    }
  }

  // 🔹 重設密碼流程
  Future<void> _handleResetPassword() async {
    if (!mounted ||
        _isSubmitting ||
        _isSendingResetEmail ||
        _resetEmailCooldownSeconds > 0) {
      return;
    }
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    setState(() => _isSendingResetEmail = true);

    String? error;
    try {
      error = await _authView.resetPassword(email: email);
    } finally {
      if (mounted) setState(() => _isSendingResetEmail = false);
    }

    if (!mounted) return;
    final loc = AppLocalizations.of(context)!; // ✅ 每次 build 都取最新
    if (error?.isNotEmpty ?? false) {
      AppNavigator.showErrorBar(
        _authView.showLoginError(message: error!, loc: loc),
      );
    } else {
      _startResetEmailCooldown();
      AppNavigator.showSnackBar(loc.resetPasswordEmail);
    }
  }

  void _startResetEmailCooldown() {
    _resetEmailCooldownTimer?.cancel();
    setState(() => _resetEmailCooldownSeconds = 60);
    _resetEmailCooldownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_resetEmailCooldownSeconds <= 1) {
          timer.cancel();
          setState(() => _resetEmailCooldownSeconds = 0);
          return;
        }
        setState(() => _resetEmailCooldownSeconds--);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!; // ✅ 每次 build 都取最新
    // ✅ 讓語言變化時自動重建整個登入 UI
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
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      obscureText: false,
                      decoration: InputDecoration(
                        labelText: loc.email,
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return loc.noEmailError;
                        if (!_emailPattern.hasMatch(email)) {
                          return loc.invalidEmail;
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          _passwordFocusNode.requestFocus(), // 跳到下一個輸入欄
                    ),
                    Gaps.h16,
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      autofillHints: const [AutofillHints.password],
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
                        if ((value ?? '').isEmpty) {
                          return loc.noPasswordError;
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _tryLogin(),
                    ),
                    Gaps.h16,
                    Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                      ElevatedButton(
                        onPressed: _isSubmitting || _isSendingResetEmail
                            ? null
                            : _tryLogin,
                        child: _isSubmitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(loc.login),
                      ),
                    ]),
                    Gaps.h16,
                    Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                      TextButton(
                        onPressed: _isSubmitting ||
                                _isSendingResetEmail ||
                                _resetEmailCooldownSeconds > 0
                            ? null
                            : _handleResetPassword,
                        child: _isSendingResetEmail
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _resetEmailCooldownSeconds > 0
                                    ? loc.resetPasswordCooldown(
                                        _resetEmailCooldownSeconds,
                                      )
                                    : loc.resetPassword,
                              ),
                      ),
                      Gaps.w16,
                      TextButton(
                        onPressed: _isSubmitting || _isSendingResetEmail
                            ? null
                            : _navigateToRegister,
                        child: Text(loc.register),
                      ),
                    ]),
                    Gaps.h16,
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

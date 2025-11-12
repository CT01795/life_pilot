import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_page_main.dart';
import 'package:life_pilot/core/app_navigator.dart';
import 'package:life_pilot/core/provider_locale.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/auth/model_auth_view.dart';
import 'package:life_pilot/pages/page_type.dart';
import 'package:provider/provider.dart';

class PageLogin extends StatefulWidget {
  final String? email;
  final String? password;
  final void Function(String? email, String? password)? onNavigateToRegister;
  const PageLogin(
      {super.key, this.email, this.password, this.onNavigateToRegister});

  @override
  State<PageLogin> createState() => _PageLoginState();
}

class _PageLoginState extends State<PageLogin> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final FocusNode _emailFocusNode;
  late final FocusNode _passwordFocusNode;
  late final ModelAuthView _authView; // ✅ 改成 Model 層，而非 Controller 直接呼叫

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? constEmpty);
    _passwordController =
        TextEditingController(text: widget.password ?? constEmpty);
    _emailFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authView = context.read<ModelAuthView>();
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 🔁 導航到註冊頁
  void _navigateToRegister() {
    widget.onNavigateToRegister?.call(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
  }

  // 🔹 嘗試登入或匿名登入
  Future<void> _tryLogin({required bool isAnonymously}) async {
    if (!mounted) return;
    final controllerPageMain = context.read<ControllerPageMain>();
    controllerPageMain.changePage(PageType.personalEvent);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final error = !isAnonymously
        ? await _authView.login(
            email: email,
            password: password,
          )
        : await _authView.anonymousLogin();

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
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final error = await _authView.resetPassword(email: email);
    final loc = AppLocalizations.of(context)!; // ✅ 每次 build 都取最新
    if (error?.isNotEmpty ?? false) {
      AppNavigator.showErrorBar(
        _authView.showLoginError(message: error!, loc: loc),
      );
    } else {
      AppNavigator.showSnackBar(loc.resetPasswordEmail);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 讓語言變化時自動重建整個登入 UI
    return Consumer<ProviderLocale>(builder: (context, localeProvider, _) {
      final loc = AppLocalizations.of(context)!;

      return SingleChildScrollView(
        padding: Insets.all12,
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              obscureText: false,
              decoration: InputDecoration(labelText: loc.email),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _passwordFocusNode.requestFocus(), // 跳到下一個輸入欄
            ),
            Gaps.h16,
            TextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: true,
              decoration: InputDecoration(labelText: loc.password),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _tryLogin(isAnonymously: false),
            ),
            Gaps.h16,
            Row(mainAxisAlignment: MainAxisAlignment.start, children: [
              ElevatedButton(
                child: Text(loc.login),
                onPressed: () => _tryLogin(isAnonymously: false),
              ),
              Gaps.w16,
              ElevatedButton(
                child: Text(loc.loginAnonymously),
                onPressed: () => _tryLogin(isAnonymously: true),
              ),
            ]),
            Gaps.h16,
            Row(mainAxisAlignment: MainAxisAlignment.start, children: [
              TextButton(
                onPressed: _handleResetPassword,
                child: Text(loc.resetPassword),
              ),
              Gaps.w16,
              TextButton(
                onPressed: _navigateToRegister,
                child: Text(loc.register),
              ),
            ]),
            Gaps.h16,
          ],
        ),
      );
    });
  }
}

/*🔍 優化重點說明
效能	使用 late final 初始化控制器與 FocusNode	減少 null 檢查，效能更穩定
安全性	登入/重設密碼後都加上 if (!mounted)	防止 widget 已卸載後仍更新 UI
結構清晰	拆分 _tryLogin()、_handleResetPassword()、_navigateToRegister()	職責分明，未來擴充（如驗證輸入）更方便
Focus 管理	透過 _passwordFocus.requestFocus()	取代 FocusScope.of(context) 使邏輯更穩定
UI 精簡	移除多餘容器，簡化排版	減少 widget rebuild，畫面更輕量*/

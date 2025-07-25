import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/services/service_auth.dart';
import 'package:life_pilot/utils/gaps.dart';
import 'package:life_pilot/utils/handler_message.dart';
import 'package:life_pilot/utils/ui_input_field.dart';
import 'package:provider/provider.dart';

class PageLogin extends StatefulWidget {
  final String? email; // 新增 email 欄位來儲存傳入的 email
  final String? password;
  final void Function(String? email, String? password)? onNavigateToRegister;
  const PageLogin({super.key, this.email, this.password, this.onNavigateToRegister});

  @override
  State<PageLogin> createState() => _PageLoginState();
}

class _PageLoginState extends State<PageLogin> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 初始化 _emailController，將傳入的 email 設置為控制器的文本
    _emailController.text = widget.email ?? ''; // 安全起見加 ??
    _passwordController.text = widget.password ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    final loc = AppLocalizations.of(context)!;
    final result = await ServiceAuth.login(
      _emailController.text,
      _passwordController.text,
    );

    if (result == null) {
      final auth = Provider.of<ControllerAuth>(context, listen: false);
      await auth.checkLoginStatus(); // ✅ 通知狀態變更
      // 登入成功後會在外層重新渲染畫面，不用 Navigator.pushReplacement 了
    } else {
      showLoginError(context, result, loc); // 使用共用的錯誤處理函數
    }
  }

  void _anonymousLogin() async {
    final loc = AppLocalizations.of(context)!;
    final auth = Provider.of<ControllerAuth>(context, listen: false);
    final result = await auth.anonymousLogin();
    if (result != null) {
      showLoginError(context, result, loc);
    }
  }

  // 重設密碼功能
  void _resetPassword() async {
    final loc = AppLocalizations.of(context)!;
    final result = await ServiceAuth.resetPassword(_emailController.text);

    if (result == null) {
      showMessage(context, loc.resetPasswordEmail);
    } else {
      showLoginError(context, result, loc); // 使用共用的錯誤處理函數
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            InputField(controller: _emailController, labelText: loc.email),
            InputField(
                controller: _passwordController,
                labelText: loc.password,
                obscureText: true),
            kGapH16,
            Row(mainAxisAlignment: MainAxisAlignment.start, children: [
              ActionButton(label: loc.login, onPressed: _login), // 使用共用的按鈕組件
              kGapW16,
              ActionButton(
                  label: loc.resetPassword,
                  onPressed: _resetPassword), // 使用共用的按鈕組件
              kGapW16,
              TextButton(
                onPressed: () {
                  widget.onNavigateToRegister?.call(
                    _emailController.text,
                    _passwordController.text,
                  );
                },
                child: Text(loc.register),
              ),
              kGapW16,
              TextButton(
                onPressed: _anonymousLogin,
                child: Text(loc.loginAnonymously),
              ),
              kGapW16,
            ])
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/services/service_auth.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/widget/utils_input_field.dart';
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late ControllerAuth _auth;
  late AppLocalizations _loc;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email ?? constEmpty;
    _passwordController.text = widget.password ?? constEmpty;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loc = AppLocalizations.of(context)!;
    _auth = Provider.of<ControllerAuth>(context, listen: true);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    FocusScope.of(context).unfocus(); // 收鍵盤
    final result = await ServiceAuth.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );


    if (result == null) {
      await _auth.checkLoginStatus();
      // 登入成功後會在外層重新渲染畫面，不用 Navigator.pushReplacement 了
    } else {
      showLoginError(message: result, loc: _loc);
    }
  }

  void _anonymousLogin() async {
    FocusScope.of(context).unfocus();
    final result = await _auth.anonymousLogin();


    if (result != null) {
      showLoginError(message: result, loc: _loc);
    }
  }

  void _resetPassword() async {
    final result = await ServiceAuth.resetPassword(_emailController.text.trim());

    if (result == null) {
      showSnackBar(message: _loc.resetPasswordEmail);
    } else {
      showLoginError(message: result, loc: _loc);
    }
  }

  // 🔁 導航到註冊頁
  void _navigateToRegister() {
    widget.onNavigateToRegister?.call(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: kGapEI12,
        child: Column(
          children: [
            InputField(controller: _emailController, labelText: _loc.email),
            kGapH16(),
            InputField(
                controller: _passwordController,
                labelText: _loc.password,
                obscureText: true),
            kGapH16(),
            Row(mainAxisAlignment: MainAxisAlignment.start, children: [
              ActionButton(label: _loc.login, onPressed: _login),
              kGapW16(),
              ActionButton(
                  label: _loc.loginAnonymously, onPressed: _anonymousLogin),
            ]),
            kGapH16(),
            Row(mainAxisAlignment: MainAxisAlignment.start, children: [
              TextButton(
                onPressed: _resetPassword,
                child: Text(_loc.resetPassword),
              ),
              kGapW16(),
              TextButton(
                onPressed: _navigateToRegister,
                child: Text(_loc.register),
              ),
            ]),
            kGapH16(),
          ],
        ),
      ),
    );
  }
}

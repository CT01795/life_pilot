import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/services/service_auth.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:life_pilot/utils/utils_input_field.dart';
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
  AppLocalizations get loc => AppLocalizations.of(context)!; 

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email ?? constEmpty; 
    _passwordController.text = widget.password ?? constEmpty;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    final result = await ServiceAuth.login(
      _emailController.text,
      _passwordController.text,
    );

    if (result == null) {
      final auth = Provider.of<ControllerAuth>(context, listen: false);
      await auth.checkLoginStatus(); 
      // 登入成功後會在外層重新渲染畫面，不用 Navigator.pushReplacement 了
    } else {
      showLoginError(context, result, loc); 
    }
  }

  void _anonymousLogin() async {
    final auth = Provider.of<ControllerAuth>(context, listen: false);
    final result = await auth.anonymousLogin();
    if (result != null) {
      showLoginError(context, result, loc);
    }
  }

  void _resetPassword() async {
    final result = await ServiceAuth.resetPassword(_emailController.text);

    if (result == null) {
      showSnackBar(context, loc.resetPasswordEmail);
    } else {
      showLoginError(context, result, loc); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: kGapEI12,
        child: Column(
          children: [
            InputField(controller: _emailController, labelText: loc.email),
            kGapH16(),
            InputField(
                controller: _passwordController,
                labelText: loc.password,
                obscureText: true),
            kGapH16(),
            Row(mainAxisAlignment: MainAxisAlignment.start, children: [
              ActionButton(label: loc.login, onPressed: _login), 
              kGapW16(),
              ActionButton(
                  label: loc.loginAnonymously, onPressed: _anonymousLogin),
            ]),
            kGapH16(),
            Row(mainAxisAlignment: MainAxisAlignment.start, children: [
              TextButton(
                onPressed: _resetPassword,
                child: Text(loc.resetPassword),
              ), 
              kGapW16(),
              TextButton(
                onPressed: () {
                  widget.onNavigateToRegister?.call(
                    _emailController.text,
                    _passwordController.text,
                  );
                },
                child: Text(loc.register),
              ),
            ]),
            kGapH16(),
          ],
        ),
      ),
    );
  }
}

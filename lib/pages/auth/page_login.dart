import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
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
    _auth = Provider.of<ControllerAuth>(context, listen: false);
  }

  @override
  void dispose() {
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
              ActionButton(
                  label: _loc.login,
                  onPressed: () async {
                    FocusScope.of(context).unfocus();
                    final error = await _auth.login(
                        email: _emailController.text.trim(),
                        password: _passwordController.text.trim());
                    if (error != null && error.isNotEmpty) {
                      showLoginError(message: error, loc: _loc);
                    }
                  }),
              kGapW16(),
              ActionButton(
                label: _loc.loginAnonymously,
                onPressed: () async {
                  FocusScope.of(context).unfocus();
                  final error = await _auth.anonymousLogin();
                  if (error != null) {
                    showLoginError(message: error, loc: _loc);
                  }
                },
              ),
            ]),
            kGapH16(),
            Row(mainAxisAlignment: MainAxisAlignment.start, children: [
              TextButton(
                onPressed: () async {
                  FocusScope.of(context).unfocus();
                  final error = await _auth.resetPassword(
                      email: _emailController.text.trim());
                  if (error != null && error.isNotEmpty) {
                    showLoginError(message: error, loc: _loc);
                  } else {
                    showSnackBar(message: _loc.resetPasswordEmail);
                  }
                },
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

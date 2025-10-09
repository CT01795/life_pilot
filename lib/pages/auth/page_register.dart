import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/widget/utils_input_field.dart';
import 'package:provider/provider.dart';

class PageRegister extends StatefulWidget {
  final String? email;
  final String? password;
  final void Function(String email, String password) onBack;
  const PageRegister(
      {super.key, this.email, this.password, required this.onBack});

  @override
  State<PageRegister> createState() => _PageRegisterState();
}

class _PageRegisterState extends State<PageRegister> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late ControllerAuth _auth;
  late AppLocalizations _loc;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? constEmpty);
    _passwordController =
        TextEditingController(text: widget.password ?? constEmpty);
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Theme(
        data: Theme.of(context),
        child: SingleChildScrollView(
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
              Row(
                children: [
                  ActionButton(
                    label: _loc.register, 
                    onPressed: () async {
                      FocusScope.of(context).unfocus();
                      final error = await _auth.register(
                          email: _emailController.text.trim(),
                          password: _passwordController.text.trim());
                      if (error != null && error.isNotEmpty) {
                        showLoginError(message: error, loc: _loc);
                      }
                    }),
                  kGapW8(),
                  TextButton(
                    onPressed: () {
                      widget.onBack(
                        _emailController.text,
                        _passwordController.text,
                      );
                    },
                    child: Text(_loc.back),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

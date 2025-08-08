import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/services/service_auth.dart';
import 'package:life_pilot/utils/utils_gaps.dart';
import 'package:life_pilot/utils/utils_handler_message.dart';
import 'package:life_pilot/utils/utils_class_input_field.dart';
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  AppLocalizations get loc => AppLocalizations.of(context)!; 

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email ?? '';
    _passwordController.text = widget.password ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _register() async {
    final result = await ServiceAuth.register(
      _emailController.text,
      _passwordController.text,
    );

    if (result == null) {
      final auth = Provider.of<ControllerAuth>(context, listen: false);
      await auth.checkLoginStatus();
    } else {
      showLoginError(context, result, loc); 
    }
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
              InputField(controller: _emailController, labelText: loc.email),
              kGapH16,
              InputField(
                  controller: _passwordController,
                  labelText: loc.password,
                  obscureText: true),
              kGapH16,
              Row(
                children: [
                  ActionButton(
                      label: loc.register, onPressed: _register), 
                  kGapW8,
                  TextButton(
                    onPressed: () {
                      widget.onBack(
                        _emailController.text,
                        _passwordController.text,
                      );
                    },
                    child: Text(loc.back),
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

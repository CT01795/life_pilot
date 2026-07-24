import 'package:flutter/material.dart';
import 'package:life_pilot/auth/app_shell.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/auth/page_login.dart';
import 'package:life_pilot/auth/page_register.dart';
import 'package:life_pilot/auth/page_reset_password.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:provider/provider.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProviderLocale>(builder: (context, localeProvider, _) {
      return Selector<ModelAuthView, AuthPage>(
        selector: (_, model) => model.currentPage,
        builder: (_, page, __) {
          switch (page) {
            case AuthPage.login:
              return PageLogin(
                key: ValueKey(localeProvider.locale),
              );
            case AuthPage.register:
              return PageRegister(
                key: ValueKey(localeProvider.locale),
              );
            case AuthPage.resetPassword:
              return PageResetPassword(
                key: ValueKey(localeProvider.locale),
              );
            case AuthPage.pageMain:
              return const AppShell();
          }
        },
      );
    });
  }
}
